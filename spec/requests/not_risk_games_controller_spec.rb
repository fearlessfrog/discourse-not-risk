# frozen_string_literal: true

RSpec.describe NotRisk::GamesController do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, trust_level: 1) }
  fab!(:other_user, :user)
  fab!(:third_user, :user)
  fab!(:fourth_user, :user)
  fab!(:fifth_user, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: admin) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: admin, post_number: 1, raw: "Campaign log") }

  before do
    SiteSetting.not_risk_enabled = true
    SiteSetting.not_risk_game_categories = ""
  end

  it "lets an authorized member create a campaign in a configured category" do
    SiteSetting.not_risk_game_categories = category.id.to_s
    sign_in(user)

    post "/not-risk/games.json",
         params: {
           category_id: category.id,
           name: "Member Campaign",
           description: "Opening campaign notes",
         }

    expect(response.status).to eq(200)
    json = response.parsed_body
    game = NotRisk::Game.find(json.dig("game", "id"))
    expect(game.topic).to have_attributes(user_id: user.id, category_id: category.id, title: "Member Campaign")
    expect(game.topic.first_post.raw).to include("Opening campaign notes", "[not-risk game=#{game.id}]")
    expect(game.players.pluck(:user_id, :position)).to eq([[user.id, 0]])
    expect(game.events.order(:id).pluck(:event_type)).to eq(%w[game_created player_joined])
    expect(json["permissions"]).to include(
      "is_participant" => true,
      "can_join" => false,
      "can_start" => false,
    )
  end

  it "rejects self-service creation outside configured categories" do
    sign_in(user)

    post "/not-risk/games.json", params: { category_id: category.id, name: "No Campaign Here" }

    expect(response.status).to eq(422)
    expect(NotRisk::Game.count).to eq(0)
  end

  it "respects read-only category permissions for self-service creation" do
    category.set_permissions(everyone: :readonly, staff: :full)
    category.save!
    SiteSetting.not_risk_game_categories = category.id.to_s
    sign_in(user)

    post "/not-risk/games.json", params: { category_id: category.id, name: "Read-only Campaign" }

    expect(response.status).to eq(422)
    expect(NotRisk::Game.count).to eq(0)
  end

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

  it "caps setup games at four players" do
    sign_in(admin)
    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Four Player Campaign" }
    game_id = response.parsed_body.dig("game", "id")

    [user, other_user, third_user, fourth_user].each do |joining_user|
      sign_in(joining_user)
      post "/not-risk/games/#{game_id}/join.json"
      expect(response.status).to eq(200)
    end

    sign_in(fifth_user)
    post "/not-risk/games/#{game_id}/join.json"

    expect(response.status).to eq(422)
    expect(NotRisk::Game.find(game_id).players.count).to eq(4)
  end

  it "allows the creator or staff to start but not another participant" do
    SiteSetting.not_risk_game_categories = category.id.to_s
    sign_in(user)
    post "/not-risk/games.json", params: { category_id: category.id, name: "Hosted Campaign" }
    game_id = response.parsed_body.dig("game", "id")

    sign_in(other_user)
    post "/not-risk/games/#{game_id}/join.json"
    post "/not-risk/games/#{game_id}/start.json"
    expect(response.status).to eq(422)

    sign_in(user)
    get "/not-risk/games/#{game_id}.json"
    expect(response.parsed_body.dig("permissions", "can_start")).to eq(true)
    post "/not-risk/games/#{game_id}/start.json"
    expect(response.status).to eq(200)

    second_topic = Fabricate(:topic, user: admin)
    Fabricate(:post, topic: second_topic, user: admin, post_number: 1, raw: "Second campaign")
    sign_in(admin)
    post "/not-risk/games.json", params: { topic_id: second_topic.id, name: "Staff Campaign" }
    second_game_id = response.parsed_body.dig("game", "id")
    post "/not-risk/games/#{second_game_id}/join.json", params: { user_id: user.id }
    post "/not-risk/games/#{second_game_id}/join.json", params: { user_id: other_user.id }
    post "/not-risk/games/#{second_game_id}/start.json"
    expect(response.status).to eq(200)
  end

  it "serializes join and start permissions for viewers" do
    game =
      NotRisk::Game.create!(
        topic: topic,
        name: "Permission Campaign",
        status: "setup",
        current_phase: "reinforce",
        turn_number: 1,
        map_key: NotRisk::Maps::Fantasy12Risklike::KEY,
        settings: {},
        created_by: user,
      )
    game.players.create!(user: user, color: NotRisk::GameEngine::PLAYER_COLORS.first, position: 0)
    game_id = game.id

    get "/not-risk/games/#{game_id}.json"
    expect(response.parsed_body["permissions"]).to include(
      "logged_in" => false,
      "is_participant" => false,
      "can_join" => false,
      "can_start" => false,
    )

    sign_in(other_user)
    get "/not-risk/games/#{game_id}.json"
    expect(response.parsed_body["permissions"]).to include("can_join" => true, "can_start" => false)

    post "/not-risk/games/#{game_id}/join.json"
    expect(response.parsed_body["permissions"]).to include("is_participant" => true, "can_join" => false)

    sign_in(admin)
    get "/not-risk/games/#{game_id}.json"
    expect(response.parsed_body["permissions"]).to include("can_start" => true)
    expect(response.parsed_body["game"]).to include("created_by_id" => user.id, "max_players" => 4)
  end

  it "rejects attaching a second game to the same topic" do
    sign_in(admin)
    post "/not-risk/games.json", params: { topic_id: topic.id, name: "First Campaign" }
    expect(response.status).to eq(200)

    post "/not-risk/games.json", params: { topic_id: topic.id, name: "Duplicate Campaign" }

    expect(response.status).to eq(422)
    expect(NotRisk::Game.where(topic_id: topic.id).count).to eq(1)
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
