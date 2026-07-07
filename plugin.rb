# frozen_string_literal: true

# name: discourse-not-risk
# about: A forum-native, turn-based strategy campaign game for Discourse.
# version: 0.1.0
# authors: fearlessfrog and Discourse Not Risk Contributors
# url: https://github.com/fearlessfrog/discourse-not-risk
# required_version: 2.7.0

enabled_site_setting :not_risk_enabled

register_asset "stylesheets/common/not-risk.scss"

module ::NotRisk
  PLUGIN_NAME = "discourse-not-risk"
end

require_relative "lib/not_risk/engine"

after_initialize do
  require_relative "lib/not_risk/error"
  require_relative "lib/not_risk/maps/mudspike"
  require_relative "lib/not_risk/maps/fantasy_12_risklike"
  require_relative "lib/not_risk/game_engine"
  require_relative "app/models/not_risk/game"
  require_relative "app/models/not_risk/player"
  require_relative "app/models/not_risk/territory"
  require_relative "app/models/not_risk/event"
  require_relative "app/controllers/not_risk/games_controller"

  Discourse::Application.routes.prepend do
    get "/not-risk/games/:id" => "list#latest", constraints: ->(request) { request.format.html? }
  end

  Discourse::Application.routes.append { mount ::NotRisk::Engine, at: "/not-risk" }
end
