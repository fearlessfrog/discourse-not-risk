# frozen_string_literal: true

module ::NotRisk
  class GamesController < ::ApplicationController
    requires_plugin NotRisk::PLUGIN_NAME

    before_action :ensure_logged_in, except: %i[show]

    def show
      render json: engine.show(game)
    rescue NotRisk::Error => e
      render_json_error e.message
    end

    def create
      render json:
               engine.create(
                 topic_id: params[:topic_id],
                 category_id: params[:category_id],
                 name: params[:name],
                 description: params[:description],
               )
    rescue NotRisk::Error => e
      render_json_error e.message
    end

    def join
      render json: engine.join(game, user_id: params[:user_id])
    rescue NotRisk::Error => e
      render_json_error e.message
    end

    def start
      render json: engine.start(game)
    rescue NotRisk::Error => e
      render_json_error e.message
    end

    def deploy
      render json:
               engine.deploy(
                 game,
                 territory_key: params.require(:territory_key),
                 armies: params.require(:armies),
               )
    rescue NotRisk::Error => e
      render_json_error e.message
    end

    def attack
      render json:
               engine.attack(
                 game,
                 from_key: params.require(:from_key),
                 to_key: params.require(:to_key),
                 attack_armies: params[:attack_armies],
                 move_armies: params[:move_armies],
               )
    rescue NotRisk::Error => e
      render_json_error e.message
    end

    def advance_to_fortify
      render json: engine.advance_to_fortify(game)
    rescue NotRisk::Error => e
      render_json_error e.message
    end

    def fortify
      render json:
               engine.fortify(
                 game,
                 from_key: params.require(:from_key),
                 to_key: params.require(:to_key),
                 armies: params.require(:armies),
               )
    rescue NotRisk::Error => e
      render_json_error e.message
    end

    def end_turn
      render json: engine.end_turn(game)
    rescue NotRisk::Error => e
      render_json_error e.message
    end

    private

    def game
      @game ||= Game.find_by(id: params.require(:id)) || raise(Discourse::NotFound)
    end

    def engine
      @engine ||= GameEngine.new(user: current_user, guardian: guardian)
    end
  end
end
