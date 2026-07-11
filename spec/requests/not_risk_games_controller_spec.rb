# frozen_string_literal: true

RSpec.describe NotRisk::GamesController do
  fab!(:admin)
  fab!(:user)
  fab!(:other_user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, user: admin) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: admin, post_number: 1, raw: "Campaign log") }

  before { SiteSetting.not_risk_enabled = true }

  it "allows staff to create a game" do
    sign_in(admin)

    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Mudspike Test" }

    expect(response.status).to eq(200)
    json = response.parsed_body
    expect(json["game"]["name"]).to eq("Mudspike Test")
    expect(topic.first_post.reload.raw).to include("[not-risk game=#{json["game"]["id"]}]")
  end

  it "does not allow non-staff to create a game" do
    sign_in(user)

    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Mudspike Test" }

    expect(response.status).to eq(422)
  end

  it "allows anonymous users to view a game attached to a visible topic" do
    sign_in(admin)
    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Mudspike Test" }
    game_id = response.parsed_body["game"]["id"]
    sign_out

    get "/not-risk/games/#{game_id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["game"]["id"]).to eq(game_id)
    expect(response.parsed_body["map"]["background_image_url"]).to eq(
      "/plugins/discourse-not-risk/images/fantasy-12-small.jpg",
    )
    expect(response.parsed_body["map"]["territories"].map { |territory| territory["key"] }).to include(
      "northwest_forest",
      "central_kingdom",
      "isle_of_mists",
    )
  end

  it "serves the Discourse app shell for the War Room html route" do
    sign_in(admin)
    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Mudspike Test" }
    game_id = response.parsed_body["game"]["id"]

    get "/not-risk/games/#{game_id}", headers: { "ACCEPT" => "text/html" }

    expect(response.status).to eq(200)
    expect(response.media_type).to eq("text/html")
  end

  it "allows users to join themselves but not add another user" do
    sign_in(admin)
    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Mudspike Test" }
    game_id = response.parsed_body["game"]["id"]

    sign_in(user)
    post "/not-risk/games/#{game_id}/join.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["players"].map { |player| player["user_id"] }).to include(user.id)

    post "/not-risk/games/#{game_id}/join.json", params: { user_id: other_user.id }
    expect(response.status).to eq(422)
  end

  it "starts a staff-created game and returns JSON state" do
    sign_in(admin)
    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Mudspike Test" }
    game_id = response.parsed_body["game"]["id"]
    post "/not-risk/games/#{game_id}/join.json", params: { user_id: user.id }
    post "/not-risk/games/#{game_id}/join.json", params: { user_id: other_user.id }

    post "/not-risk/games/#{game_id}/start.json"

    expect(response.status).to eq(200)
    json = response.parsed_body
    expect(json["territories"].length).to eq(12)
    expect(json["game"]["map_key"]).to eq("fantasy_12_risklike")
    expect(json["game"]["current_phase"]).to eq("reinforce")
  end

  it "allows the current player to advance from attack to fortify" do
    sign_in(admin)
    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Mudspike Test" }
    game_id = response.parsed_body["game"]["id"]
    post "/not-risk/games/#{game_id}/join.json", params: { user_id: user.id }
    post "/not-risk/games/#{game_id}/join.json", params: { user_id: other_user.id }
    post "/not-risk/games/#{game_id}/start.json"

    game = NotRisk::Game.find(game_id)
    game.update!(current_phase: "attack")
    sign_in(game.current_player.user)

    post "/not-risk/games/#{game_id}/advance_to_fortify.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["game"]["current_phase"]).to eq("fortify")
  end

  it "returns an action result only for a successful attack request" do
    sign_in(admin)
    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Mudspike Test" }
    game_id = response.parsed_body["game"]["id"]
    post "/not-risk/games/#{game_id}/join.json", params: { user_id: user.id }
    post "/not-risk/games/#{game_id}/join.json", params: { user_id: other_user.id }
    post "/not-risk/games/#{game_id}/start.json"

    game = NotRisk::Game.find(game_id)
    current_player = game.current_player
    source =
      game.territories.find do |territory|
        territory.owner_player_id == current_player.id &&
          NotRisk::Maps::Fantasy12Risklike
          .territory(territory.territory_key)[:adjacent]
          .any? do |key|
            game.territories.find_by(territory_key: key).owner_player_id != current_player.id
          end
      end
    target_key =
      NotRisk::Maps::Fantasy12Risklike
        .territory(source.territory_key)[:adjacent]
        .find { |key| game.territories.find_by(territory_key: key).owner_player_id != current_player.id }
    source.update!(armies: 3)
    game.update!(current_phase: "attack")
    sign_in(current_player.user)

    post "/not-risk/games/#{game_id}/attack.json",
         params: {
           from_key: source.territory_key,
           to_key: target_key,
           attack_armies: 1,
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["action_result"]).to include(
      "from" => source.territory_key,
      "to" => target_key,
      "source_armies_before" => 3,
    )

    get "/not-risk/games/#{game_id}.json"
    expect(response.parsed_body).not_to have_key("action_result")

    post "/not-risk/games/#{game_id}/attack.json",
         params: {
           from_key: source.territory_key,
           to_key: source.territory_key,
           attack_armies: 1,
         }

    expect(response.status).to eq(422)
    expect(response.parsed_body).not_to have_key("action_result")
  end
end
