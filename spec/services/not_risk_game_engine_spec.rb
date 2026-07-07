# frozen_string_literal: true

RSpec.describe NotRisk::GameEngine do
  fab!(:admin)
  fab!(:user)
  fab!(:other_user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, user: admin) }
  fab!(:first_post) { Fabricate(:post, topic: topic, user: admin, post_number: 1, raw: "Campaign log") }

  let(:guardian) { Guardian.new(admin) }
  let(:engine) { described_class.new(user: admin, guardian: guardian) }

  def rng_with(*rolls)
    Class
      .new do
        define_method(:initialize) { |values| @rolls = values }

        def rand(_range)
          @rolls.shift || 1
        end
      end
      .new(rolls)
  end

  def set_owner(game, player, keys)
    game.territories.where(territory_key: keys).update_all(owner_player_id: player.id)
  end

  def engine_for(player, rng: Random)
    described_class.new(user: player.user, guardian: Guardian.new(player.user), rng: rng)
  end

  def create_started_game
    state = engine.create(topic_id: topic.id, name: "Mudspike Test")
    game = NotRisk::Game.find(state[:game][:id])
    engine.join(game, user_id: user.id)
    engine.join(game, user_id: other_user.id)
    described_class.new(user: admin, guardian: guardian, rng: rng_with(6, 1)).start(game)
    game.reload
  end

  it "creates a game and appends a safe placeholder to the first post" do
    state = engine.create(topic_id: topic.id, name: "Mudspike Test")

    expect(state[:game][:name]).to eq("Mudspike Test")
    expect(state[:game][:map_key]).to eq(NotRisk::Maps::Fantasy12Risklike::KEY)
    expect(state[:map][:background_image_url]).to eq("/plugins/discourse-not-risk/images/fantasy-12-small.png")
    expect(state[:map][:image_size]).to eq(width: 1536, height: 1024)
    expect(state[:map][:view_box]).to eq("0 0 1000 667")
    expect(state[:map][:groups].keys).to include(:northlands, :southlands)
    expect(NotRisk::Maps::Fantasy12Risklike.adjacent?("dark_marsh", "isle_of_mists")).to eq(true)
    expect(topic.first_post.reload.raw).to include("[not-risk game=#{state[:game][:id]}]")
    expect(NotRisk::Event.last.event_type).to eq("game_created")
  end

  it "starts a game by assigning all Fantasy 12 territories" do
    game = create_started_game

    expect(game.status).to eq("active")
    expect(game.current_phase).to eq("reinforce")
    expect(game.territories.count).to eq(12)
    expect(game.territories.pluck(:territory_key)).to include("northwest_forest", "central_kingdom", "isle_of_mists")
    expect(game.players.order(:position).first.id).to eq(game.current_player_id)
  end

  it "randomizes starting ownership without giving one player every bonus territory" do
    game = create_started_game
    bonus_keys = NotRisk::GameEngine::TERRITORY_BONUSES.keys

    bonus_owner_ids =
      game.territories.where(territory_key: bonus_keys).pluck(:owner_player_id)

    expect(bonus_owner_ids.uniq.length).to be > 1

    event = game.events.where(event_type: "game_started").last
    assigned_bonus_keys = event.payload["territory_assignments"].pluck("territory") & bonus_keys
    expect(assigned_bonus_keys.sort).to eq(bonus_keys.sort)
  end

  it "adds one random non-bonus territory bonus for the game" do
    game = create_started_game
    fixed_bonus_keys = NotRisk::GameEngine::TERRITORY_BONUSES.keys
    active_bonuses = game.settings.fetch("territory_bonuses")
    dynamic_bonus_keys = active_bonuses.keys - fixed_bonus_keys

    expect(dynamic_bonus_keys.length).to eq(1)
    expect(active_bonuses.fetch(dynamic_bonus_keys.first)).to eq(1)

    event = game.events.where(event_type: "game_started").last
    expect(event.payload["territory_bonuses"]).to eq(active_bonuses)

    state = engine.show(game)
    dynamic_territory = state[:territories].find { |territory| territory[:key] == dynamic_bonus_keys.first }
    expect(dynamic_territory[:bonus]).to eq(1)
  end


  it "rolls initiative to determine player order when starting" do
    state = engine.create(topic_id: topic.id, name: "Mudspike Test")
    game = NotRisk::Game.find(state[:game][:id])
    engine.join(game, user_id: user.id)
    engine.join(game, user_id: other_user.id)

    described_class.new(user: admin, guardian: guardian, rng: rng_with(1, 6)).start(game)

    expect(game.reload.current_player.user_id).to eq(other_user.id)
    expect(game.players.order(:position).map(&:user_id)).to eq([other_user.id, user.id])

    event = game.events.where(event_type: "game_started").last
    expect(event.payload["initiative_rolls"].map { |roll| roll["roll"] }).to eq([6, 1])
    expect(event.payload["player_order"]).to eq(game.players.order(:position).pluck(:id))
  end

  it "deploys only to the current player's owned territory" do
    game = create_started_game
    current_player = game.current_player
    current_engine = engine_for(current_player)
    owned = game.territories.find_by(owner_player_id: current_player.id)
    enemy = game.territories.where.not(owner_player_id: current_player.id).first

    expect { current_engine.deploy(game, territory_key: enemy.territory_key, armies: 1) }.to raise_error(
      NotRisk::Error,
    )

    reinforcements = game.settings.dig("turn_state", "reinforcements_remaining")
    state = current_engine.deploy(game, territory_key: owned.territory_key, armies: reinforcements)
    expect(state[:game][:current_phase]).to eq("attack")
    expect(owned.reload.armies).to eq(1 + reinforcements)
  end

  it "sets reinforcements from half the territory count plus territory bonuses" do
    game = create_started_game
    current_player = game.current_player
    current_engine = engine_for(current_player)
    other_player = game.players.where.not(id: current_player.id).first

    normal_keys =
      NotRisk::Maps::Fantasy12Risklike.territories
        .map { |territory| territory[:key] }
        .reject { |key| NotRisk::GameEngine::TERRITORY_BONUSES.key?(key) }

    game.territories.update_all(owner_player_id: other_player.id)
    set_owner(game, current_player, normal_keys.first(2))
    expect(engine.send(:reinforcement_count_for, game, current_player, NotRisk::GameEngine::TERRITORY_BONUSES)).to eq(3)

    game.territories.update_all(owner_player_id: other_player.id)
    set_owner(game, current_player, %w[central_kingdom southern_bay isle_of_mists frost_peaks red_mountains])
    expect(engine.send(:reinforcement_count_for, game, current_player, NotRisk::GameEngine::TERRITORY_BONUSES)).to eq(6)

    game.territories.update_all(owner_player_id: current_player.id)
    set_owner(game, other_player, normal_keys.first(6))
    game.update!(
      current_phase: "attack",
      settings: game.settings.merge("territory_bonuses" => NotRisk::GameEngine::TERRITORY_BONUSES),
    )

    current_engine.end_turn(game)

    expect(game.reload.settings.dig("turn_state", "reinforcements_remaining")).to eq(3)
  end

  it "publishes game updates after committed actions" do
    game = create_started_game
    current_player = game.current_player
    current_engine = engine_for(current_player)
    owned = game.territories.find_by(owner_player_id: current_player.id)

    messages =
      MessageBus.track_publish("/not-risk/games/#{game.id}") do
        current_engine.deploy(game, territory_key: owned.territory_key, armies: 1)
      end

    expect(messages.length).to eq(1)
    expect(messages.first.data).to include(game_id: game.id, event_type: "deploy")
  end

  it "rejects non-current player actions" do
    game = create_started_game
    non_current = described_class.new(user: other_user, guardian: Guardian.new(other_user))
    owned = game.territories.find_by(owner_player_id: game.current_player_id)

    expect { non_current.deploy(game, territory_key: owned.territory_key, armies: 1) }.to raise_error(
      NotRisk::Error,
      I18n.t("not_risk.errors.current_player_required"),
    )
  end

  it "rejects illegal attack adjacency" do
    game = create_started_game
    player = game.current_player
    current_engine = engine_for(player)
    source = game.territories.find_by(owner_player_id: player.id)
    source.update!(armies: 4)
    game.update!(current_phase: "attack")
    non_adjacent_key =
      NotRisk::Maps::Fantasy12Risklike.territories
        .map { |territory| territory[:key] }
        .reject { |key| key == source.territory_key || NotRisk::Maps::Fantasy12Risklike.adjacent?(source.territory_key, key) }
        .first
    target = game.territories.find_by(territory_key: non_adjacent_key)
    target.update!(owner: game.players.where.not(id: player.id).first)

    expect { current_engine.attack(game, from_key: source.territory_key, to_key: target.territory_key) }.to raise_error(
      NotRisk::Error,
      I18n.t("not_risk.errors.adjacent_required"),
    )
  end

  it "resolves dice with defender winning ties" do
    game = create_started_game
    player = game.current_player
    dice_engine = engine_for(player, rng: rng_with(4, 3, 4, 3))
    defender = game.players.where.not(id: player.id).first
    source = game.territories.find_by(owner_player_id: player.id)
    target_key = NotRisk::Maps::Fantasy12Risklike.territory(source.territory_key)[:adjacent].first
    target = game.territories.find_by(territory_key: target_key)
    source.update!(armies: 5)
    target.update!(owner: defender, armies: 2)
    game.update!(current_phase: "attack")

    dice_engine.attack(game, from_key: source.territory_key, to_key: target.territory_key, attack_armies: 2, move_armies: 2)

    event = game.events.where(event_type: "attack").last
    expect(event.payload["losses"]).to eq("attacker" => 2, "defender" => 0)
    expect(event.payload["captured"]).to eq(false)
    expect(game.reload.current_phase).to eq("attack")
    expect(source.reload.armies).to eq(3)
    expect(target.reload.owner_player_id).to eq(defender.id)
    expect(target.armies).to eq(2)
  end

  it "allows repeated attacks before advancing to fortify" do
    game = create_started_game
    player = game.current_player
    dice_engine = engine_for(player, rng: rng_with(6, 1, 6, 1))
    defender = game.players.where.not(id: player.id).first
    source = game.territories.find_by(owner_player_id: player.id)
    target_key = NotRisk::Maps::Fantasy12Risklike.territory(source.territory_key)[:adjacent].first
    target = game.territories.find_by(territory_key: target_key)
    source.update!(armies: 6)
    target.update!(owner: defender, armies: 3)
    game.update!(current_phase: "attack")

    dice_engine.attack(game, from_key: source.territory_key, to_key: target.territory_key, attack_armies: 1)
    dice_engine.attack(game.reload, from_key: source.territory_key, to_key: target.territory_key, attack_armies: 1)

    expect(game.reload.current_phase).to eq("attack")
    expect(game.events.where(event_type: "attack").count).to eq(2)

    dice_engine.advance_to_fortify(game)

    expect(game.reload.current_phase).to eq("fortify")
    expect(game.events.where(event_type: "advance_to_fortify").count).to eq(1)
  end

  it "captures territory when attacker beats defender dice" do
    rng = Class.new do
      def initialize
        @rolls = [6, 6, 5, 5]
      end

      def rand(_range)
        @rolls.shift
      end
    end.new
    game = create_started_game
    player = game.current_player
    dice_engine = engine_for(player, rng: rng)
    defender = game.players.where.not(id: player.id).first
    source = game.territories.find_by(owner_player_id: player.id)
    target_key = NotRisk::Maps::Fantasy12Risklike.territory(source.territory_key)[:adjacent].first
    target = game.territories.find_by(territory_key: target_key)
    source.update!(armies: 5)
    target.update!(owner: defender, armies: 2)
    game.update!(current_phase: "attack")

    dice_engine.attack(game, from_key: source.territory_key, to_key: target.territory_key, attack_armies: 2, move_armies: 2)

    event = game.events.where(event_type: "attack").last
    expect(event.payload["attack_armies"]).to eq(2)
    expect(event.payload["attacker_dice"].length).to eq(2)
    expect(event.payload["losses"]).to eq("attacker" => 0, "defender" => 2)
    expect(event.payload["captured"]).to eq(true)
    expect(game.reload.current_phase).to eq("attack")
    expect(target.reload.owner_player_id).to eq(player.id)
    expect(target.armies).to eq(2)
  end

  it "rejects committed attack armies that would not leave one behind" do
    game = create_started_game
    player = game.current_player
    current_engine = engine_for(player, rng: rng_with(6, 5, 4, 3, 2))
    defender = game.players.where.not(id: player.id).first
    source = game.territories.find_by(owner_player_id: player.id)
    target_key = NotRisk::Maps::Fantasy12Risklike.territory(source.territory_key)[:adjacent].first
    target = game.territories.find_by(territory_key: target_key)
    source.update!(armies: 3)
    target.update!(owner: defender, armies: 3)
    game.update!(current_phase: "attack")

    expect {
      current_engine.attack(game, from_key: source.territory_key, to_key: target.territory_key, attack_armies: 9)
    }.to raise_error(NotRisk::Error, I18n.t("not_risk.errors.attack_armies_exceeded"))
  end

  it "fortifies once between adjacent owned territories" do
    game = create_started_game
    player = game.current_player
    current_engine = engine_for(player)
    source = game.territories.find_by(owner_player_id: player.id)
    target_key = NotRisk::Maps::Fantasy12Risklike.territory(source.territory_key)[:adjacent].first
    target = game.territories.find_by(territory_key: target_key)
    source.update!(armies: 4)
    target.update!(owner: player, armies: 1)
    game.update!(current_phase: "fortify")

    current_engine.fortify(game, from_key: source.territory_key, to_key: target.territory_key, armies: 2)

    expect(source.reload.armies).to eq(2)
    expect(target.reload.armies).to eq(3)
    expect {
      current_engine.fortify(game.reload, from_key: target.territory_key, to_key: source.territory_key, armies: 1)
    }.to raise_error(NotRisk::Error, I18n.t("not_risk.errors.fortify_used"))
  end

  it "ends the turn, advances player, and creates one campaign reply" do
    game = create_started_game
    ending_player = game.current_player
    next_player = game.players.where.not(id: ending_player.id).order(:position).first
    current_engine = engine_for(ending_player)
    game.update!(current_phase: "attack")

    expect { current_engine.end_turn(game) }.to change { Post.where(topic_id: topic.id).count }.by(1)

    expect(game.reload.current_player_id).to eq(next_player.id)
    expect(game.current_phase).to eq("reinforce")
    summary = topic.posts.order(:post_number).last.raw
    expect(summary).to include("Turn 1 - @#{ending_player.user.username}")
    expect(summary).to include("@#{next_player.user.username}")
  end
end
