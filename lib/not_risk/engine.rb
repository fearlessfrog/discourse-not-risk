# frozen_string_literal: true

module ::NotRisk
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace NotRisk
  end
end
