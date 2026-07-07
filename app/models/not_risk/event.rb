# frozen_string_literal: true

module ::NotRisk
  class Event < ::ActiveRecord::Base
    self.table_name = "not_risk_events"

    belongs_to :game, class_name: "NotRisk::Game"
    belongs_to :player, class_name: "NotRisk::Player", optional: true

    validates :turn_number, :event_type, presence: true
  end
end
