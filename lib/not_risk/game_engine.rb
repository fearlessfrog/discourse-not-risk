# frozen_string_literal: true

module ::NotRisk
  class GameEngine
    MIN_REINFORCEMENTS_PER_TURN = 3
    PLAYER_COLORS = %w[#c2410c #2563eb #16a34a #9333ea #ca8a04 #0891b2].freeze
    TERRITORY_BONUSES = {
      "central_kingdom" => 2,
      "southern_bay" => 1,
      "isle_of_mists" => 1,
    }.freeze

    def initialize(user:, guardian: nil, rng: Random)
      @user = user
      @guardian = guardian || Guardian.new(user)
      @rng = rng
    end

    def show(game)
      ensure_can_see!(game)
      serialize(game)
    end

    def create(topic_id:, name:)
      ensure_staff!
      topic = Topic.find_by(id: topic_id)
      raise Error, I18n.t("not_risk.errors.topic_not_found") if topic.blank?
      ensure_can_see_topic!(topic)

      game =
        Game.create!(
          topic: topic,
          name: name.presence || "Fantasy 12 Campaign",
          status: "setup",
          current_phase: "reinforce",
          turn_number: 1,
          map_key: Maps::Fantasy12Risklike::KEY,
          settings: default_settings,
          created_by: @user,
        )

      append_placeholder!(topic, game)
      record_event(game, nil, "game_created", topic_id: topic.id, name: game.name)
      serialize(game)
    end

    def join(game, user_id: nil)
      ensure_can_see!(game)
      target_user = resolve_join_user(user_id)
      raise Error, I18n.t("not_risk.errors.already_started") unless game.status == "setup"
      if game.players.exists?(user_id: target_user.id)
        raise Error, I18n.t("not_risk.errors.already_joined")
      end

      player =
        game.players.create!(
          user: target_user,
          color: PLAYER_COLORS[game.players.count % PLAYER_COLORS.length],
          position: game.players.count,
        )
      record_event(game, player, "player_joined", user_id: target_user.id, username: target_user.username)
      publish_game_update!(game, "player_joined")
      serialize(game.reload)
    end

    def start(game)
      ensure_staff!
      ensure_can_see!(game)
      raise Error, I18n.t("not_risk.errors.already_started") unless game.status == "setup"
      joined_players = game.players.order(:position).to_a
      raise Error, I18n.t("not_risk.errors.not_enough_players") if joined_players.length < 2
      initiative = roll_initiative(joined_players)
      players = initiative.map { |roll| roll[:player] }
      territory_assignments = fair_starting_assignments(Maps::Fantasy12Risklike.territories, players)

      Game.transaction do
        joined_players.each_with_index { |player, index| player.update!(position: joined_players.length + index) }
        players.each_with_index { |player, position| player.update!(position: position) }

        territory_assignments.each do |definition, player|
          game.territories.create!(
            territory_key: definition[:key],
            owner: player,
            armies: 1,
          )
        end

        territory_bonuses = territory_bonuses_with(random_game_bonus_key(Maps::Fantasy12Risklike.territories))

        game.update!(
          status: "active",
          current_player: players.first,
          current_phase: "reinforce",
          turn_number: 1,
          settings: default_settings(game, players.first, territory_bonuses),
        )
        record_event(
          game,
          nil,
          "game_started",
          player_order: players.map(&:id),
          initiative_rolls:
            initiative.map do |roll|
              {
                player_id: roll[:player].id,
                user_id: roll[:player].user_id,
                username: roll[:player].user.username,
                roll: roll[:roll],
              }
            end,
          territory_assignments:
            territory_assignments.map do |definition, player|
              { territory: definition[:key], player_id: player.id, username: player.user.username }
            end,
          territory_bonuses: territory_bonuses,
        )
      end

      publish_game_update!(game, "game_started")
      serialize(game.reload)
    end

    def deploy(game, territory_key:, armies:)
      player = ensure_current_player!(game)
      ensure_phase!(game, "reinforce")
      armies = positive_integer!(armies)
      state = turn_state(game)
      remaining = state["reinforcements_remaining"].to_i
      raise Error, I18n.t("not_risk.errors.reinforcements_exceeded") if armies > remaining

      territory = territory_for(game, territory_key)
      ensure_owned!(territory, player)

      Game.transaction do
        territory.update!(armies: territory.armies + armies)
        state["reinforcements_remaining"] = remaining - armies
        game.current_phase = "attack" if state["reinforcements_remaining"].zero?
        save_turn_state!(game, state)
        record_event(game, player, "deploy", territory: territory_key, armies: armies)
      end

      publish_game_update!(game, "deploy")
      serialize(game.reload)
    end

    def attack(game, from_key:, to_key:, attack_armies: nil, move_armies: nil)
      player = ensure_current_player!(game)
      ensure_phase!(game, "attack")
      source = territory_for(game, from_key)
      target = territory_for(game, to_key)
      ensure_owned!(source, player)
      ensure_enemy!(target, player)
      ensure_adjacent!(source.territory_key, target.territory_key)
      raise Error, I18n.t("not_risk.errors.insufficient_armies") if source.armies <= 1
      attacking_armies = attack_armies_for(attack_armies, source.armies)

      result = nil
      Game.transaction do
        attacker_dice = roll([3, attacking_armies].min)
        defender_dice = roll([2, target.armies].min)
        losses = compare_dice(attacker_dice, defender_dice)

        source.armies -= losses[:attacker]
        target.armies -= losses[:defender]
        captured = target.armies <= 0
        moved = 0

        if captured
          moved = capture_armies(move_armies || attacking_armies, source.armies)
          source.armies -= moved
          target.owner = player
          target.armies = moved
        end

        source.save!
        target.save!

        result = {
          from: source.territory_key,
          to: target.territory_key,
          attack_armies: attacking_armies,
          attacker_dice: attacker_dice,
          defender_dice: defender_dice,
          losses: losses,
          captured: captured,
          moved: moved,
        }
        record_event(game, player, "attack", result)
      end

      publish_game_update!(game, "attack")
      serialize(game.reload)
    end

    def advance_to_fortify(game)
      player = ensure_current_player!(game)
      ensure_phase!(game, "attack")

      Game.transaction do
        game.update!(current_phase: "fortify")
        record_event(game, player, "advance_to_fortify")
      end

      publish_game_update!(game, "advance_to_fortify")
      serialize(game.reload)
    end

    def fortify(game, from_key:, to_key:, armies:)
      player = ensure_current_player!(game)
      ensure_phase!(game, "fortify")
      state = turn_state(game)
      raise Error, I18n.t("not_risk.errors.fortify_used") if state["fortify_used"]

      armies = positive_integer!(armies)
      source = territory_for(game, from_key)
      target = territory_for(game, to_key)
      ensure_owned!(source, player)
      ensure_owned!(target, player)
      ensure_adjacent!(source.territory_key, target.territory_key)
      raise Error, I18n.t("not_risk.errors.insufficient_armies") if source.armies - armies < 1

      Game.transaction do
        source.update!(armies: source.armies - armies)
        target.update!(armies: target.armies + armies)
        state["fortify_used"] = true
        save_turn_state!(game, state)
        record_event(game, player, "fortify", from: from_key, to: to_key, armies: armies)
      end

      publish_game_update!(game, "fortify")
      serialize(game.reload)
    end

    def end_turn(game)
      player = ensure_current_player!(game)
      unless %w[attack fortify].include?(game.current_phase)
        raise Error, I18n.t("not_risk.errors.invalid_phase")
      end

      next_player = nil
      completed_turn = game.turn_number
      Game.transaction do
        eliminate_empty_players!(game)
        active_players = game.players.where(eliminated_at: nil).order(:position).to_a
        current_index = active_players.index { |candidate| candidate.id == player.id } || 0
        if active_players.length <= 1
          next_player = active_players.first || player
          record_event(game, player, "game_ended", winner_player_id: next_player.id)
          create_turn_summary!(game, player, next_player)
          game.update!(status: "ended", current_phase: "ended", current_player: next_player)
          next
        end

        next_index = (current_index + 1) % active_players.length
        next_player = active_players[next_index]
        next_turn_number = next_index.zero? ? game.turn_number + 1 : game.turn_number

        record_event(
          game,
          player,
          "turn_ended",
          next_player_id: next_player.id,
          next_username: next_player.user.username,
        )
        create_turn_summary!(game, player, next_player)
        game.update!(
          current_player: next_player,
          current_phase: "reinforce",
          turn_number: next_turn_number,
          settings: default_settings(game, next_player),
        )
      end

      publish_game_update!(game, "end_turn")
      serialize(game.reload).merge(completed_turn: completed_turn, next_player_id: next_player.id)
    end

    def serialize(game)
      game.reload
      players = game.players.includes(:user).order(:position).to_a
      territories = game.territories.order(:territory_key).to_a
      territory_by_key = territories.index_by(&:territory_key)

      {
        game: {
          id: game.id,
          topic_id: game.topic_id,
          name: game.name,
          status: game.status,
          current_phase: game.current_phase,
          turn_number: game.turn_number,
          current_player_id: game.current_player_id,
          map_key: game.map_key,
          settings: game.settings,
        },
        players:
          players.map do |player|
            {
              id: player.id,
              user_id: player.user_id,
              username: player.user.username,
              name: player.user.name,
              color: player.color,
              position: player.position,
              eliminated: player.eliminated_at.present?,
            }
          end,
        territories:
          Maps::Fantasy12Risklike.territories.map do |definition|
            territory = territory_by_key[definition[:key]]
            {
              key: definition[:key],
              name: definition[:name],
              owner_player_id: territory&.owner_player_id,
              armies: territory&.armies.to_i,
              bonus: territory_bonuses_for(game).fetch(definition[:key], 0),
            }
          end,
        map: Maps::Fantasy12Risklike.serialized,
        events:
          game
            .events
            .includes(player: :user)
            .order(created_at: :asc, id: :asc)
            .last(50)
            .map do |event|
              {
                id: event.id,
                player_id: event.player_id,
                username: event.player&.user&.username,
                turn_number: event.turn_number,
                event_type: event.event_type,
                payload: event.payload,
                created_at: event.created_at,
              }
            end,
      }
    end

    private

    def default_settings(game = nil, player = nil, territory_bonuses = nil)
      {
        "turn_state" => {
          "reinforcements_remaining" => reinforcement_count_for(game, player, territory_bonuses),
          "fortify_used" => false,
        },
        "territory_bonuses" => territory_bonuses || territory_bonuses_for(game),
      }
    end

    def game_channel(game)
      "/not-risk/games/#{game.id}"
    end

    def publish_game_update!(game, event_type)
      MessageBus.publish(game_channel(game), { game_id: game.id, event_type: event_type, updated_at: Time.zone.now.iso8601 })
    end

    def turn_state(game)
      game.settings.fetch("turn_state", default_settings(game, game.current_player)["turn_state"]).dup
    end

    def save_turn_state!(game, state)
      game.settings = game.settings.merge("turn_state" => state, "territory_bonuses" => territory_bonuses_for(game))
      game.save!
    end

    def resolve_join_user(user_id)
      return @user if user_id.blank?
      ensure_staff!
      User.find(user_id)
    end

    def ensure_staff!
      raise Error, I18n.t("not_risk.errors.not_allowed") unless @user&.staff?
    end

    def ensure_can_see!(game)
      ensure_can_see_topic!(game.topic)
    end

    def ensure_can_see_topic!(topic)
      raise Discourse::NotFound if topic.blank? || !@guardian.can_see?(topic)
    end

    def ensure_current_player!(game)
      ensure_can_see!(game)
      player = game.players.find_by(user_id: @user&.id)
      raise Error, I18n.t("not_risk.errors.participant_required") if player.blank?
      raise Error, I18n.t("not_risk.errors.current_player_required") if game.current_player_id != player.id
      player
    end

    def ensure_phase!(game, phase)
      raise Error, I18n.t("not_risk.errors.invalid_phase") unless game.current_phase == phase
    end

    def territory_for(game, key)
      territory = game.territories.find_by(territory_key: key)
      raise Error, I18n.t("not_risk.errors.territory_not_found") if territory.blank?
      territory
    end

    def ensure_owned!(territory, player)
      raise Error, I18n.t("not_risk.errors.owned_territory_required") unless territory.owner_player_id == player.id
    end

    def ensure_enemy!(territory, player)
      raise Error, I18n.t("not_risk.errors.enemy_territory_required") if territory.owner_player_id == player.id
      raise Error, I18n.t("not_risk.errors.enemy_territory_required") if territory.owner_player_id.blank?
    end

    def ensure_adjacent!(from_key, to_key)
      raise Error, I18n.t("not_risk.errors.adjacent_required") unless Maps::Fantasy12Risklike.adjacent?(from_key, to_key)
    end

    def positive_integer!(value)
      integer = value.to_i
      raise Error, I18n.t("not_risk.errors.armies_required") if integer <= 0
      integer
    end

    def roll(count)
      Array.new(count) { @rng.rand(1..6) }.sort.reverse
    end

    def roll_initiative(players)
      players
        .map { |player| { player: player, roll: @rng.rand(1..6), joined_position: player.position } }
        .sort_by { |roll| [-roll[:roll], roll[:joined_position]] }
    end

    def fair_starting_assignments(territories, players)
      bonus_definitions, normal_definitions =
        territories.partition { |definition| TERRITORY_BONUSES.key?(definition[:key]) }

      ordered_territories = shuffle(bonus_definitions) + shuffle(normal_definitions)
      ordered_territories.each_with_index.map { |definition, index| [definition, players[index % players.length]] }
    end

    def shuffle(items)
      items.sort_by { @rng.rand(1_000_000) }
    end

    def random_game_bonus_key(territories)
      non_bonus_definitions = territories.reject { |definition| TERRITORY_BONUSES.key?(definition[:key]) }
      shuffle(non_bonus_definitions).first[:key]
    end

    def compare_dice(attacker_dice, defender_dice)
      losses = { attacker: 0, defender: 0 }
      attacker_dice.zip(defender_dice).each do |attacker, defender|
        next if attacker.blank? || defender.blank?
        if attacker > defender
          losses[:defender] += 1
        else
          losses[:attacker] += 1
        end
      end
      losses
    end

    def reinforcement_count_for(game, player, territory_bonuses = nil)
      return MIN_REINFORCEMENTS_PER_TURN if game.blank? || player.blank?

      territory_count = game.territories.where(owner_player_id: player.id).count
      territory_bonuses ||= territory_bonuses_for(game)
      territory_bonus =
        game
          .territories
          .where(owner_player_id: player.id, territory_key: territory_bonuses.keys)
          .sum { |territory| territory_bonuses.fetch(territory.territory_key) }

      [(territory_count / 2) + territory_bonus, MIN_REINFORCEMENTS_PER_TURN].max
    end

    def territory_bonuses_for(game)
      territory_bonuses_with(game&.settings&.fetch("territory_bonuses", nil))
    end

    def territory_bonuses_with(extra_bonuses)
      extra_bonuses = { extra_bonuses => 1 } if extra_bonuses.is_a?(String)
      TERRITORY_BONUSES.merge((extra_bonuses || {}).stringify_keys)
    end

    def attack_armies_for(attack_armies, source_armies)
      requested = attack_armies.present? ? positive_integer!(attack_armies) : source_armies - 1
      raise Error, I18n.t("not_risk.errors.attack_armies_exceeded") if requested > source_armies - 1
      requested
    end

    def capture_armies(move_armies, available_after_losses)
      requested = move_armies.to_i
      requested = 1 if requested <= 0
      [[requested, available_after_losses - 1].min, 1].max
    end

    def eliminate_empty_players!(game)
      game.players.where(eliminated_at: nil).find_each do |player|
        player.update!(eliminated_at: Time.zone.now) unless game.territories.exists?(owner_player_id: player.id)
      end
    end

    def record_event(game, player, event_type, payload = {})
      game.events.create!(
        player: player,
        turn_number: game.turn_number,
        event_type: event_type,
        payload: payload,
        created_at: Time.zone.now,
      )
    end

    def append_placeholder!(topic, game)
      first_post = topic.first_post
      return if first_post.blank?
      placeholder = "[not-risk game=#{game.id}]"
      return if first_post.raw.include?(placeholder)

      PostRevisor.new(first_post, topic).revise!(
        @user,
        { raw: "#{first_post.raw.rstrip}\n\n#{placeholder}" },
        edit_reason: "Add Not Risk game placeholder",
      )
    end

    def create_turn_summary!(game, player, next_player)
      events = game.events.where(turn_number: game.turn_number, player_id: player.id).order(:created_at, :id)
      raw = turn_summary_raw(game, player, next_player, events)
      PostCreator.create!(@user || Discourse.system_user, topic_id: game.topic_id, raw: raw)
    end

    def turn_summary_raw(game, player, next_player, events)
      lines = ["Turn #{game.turn_number} - #{player.user.username}", ""]
      deploys = events.select { |event| event.event_type == "deploy" }
      attacks = events.select { |event| event.event_type == "attack" }
      fortifies = events.select { |event| event.event_type == "fortify" }

      lines << "Reinforcements:"
      if deploys.empty?
        lines << "- None"
      else
        deploys.each { |event| lines << "- +#{event.payload["armies"]} #{territory_name(event.payload["territory"])}" }
      end

      lines << ""
      lines << "Combat:"
      if attacks.empty?
        lines << "- None"
      else
        attacks.each do |event|
          payload = event.payload
          lines << "- #{territory_name(payload["from"])} attacked #{territory_name(payload["to"])}"
          lines << "  Dice: #{payload["attacker_dice"].join(', ')} vs #{payload["defender_dice"].join(', ')}"
          losses = payload["losses"]
          lines << "  Losses: attacker #{losses["attacker"]}, defender #{losses["defender"]}"
          lines << "  Captured #{territory_name(payload["to"])}" if payload["captured"]
        end
      end

      lines << ""
      lines << "Fortify:"
      if fortifies.empty?
        lines << "- None"
      else
        fortifies.each do |event|
          payload = event.payload
          lines << "- moved #{payload["armies"]} from #{territory_name(payload["from"])} to #{territory_name(payload["to"])}"
        end
      end

      lines << ""
      lines << "Next:"
      lines << "- #{next_player.user.username}"
      lines.join("\n")
    end

    def territory_name(key)
      Maps::Fantasy12Risklike.territory(key)&.dig(:name) || key
    end
  end
end
