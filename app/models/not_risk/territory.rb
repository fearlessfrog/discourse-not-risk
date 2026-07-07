# frozen_string_literal: true

module ::NotRisk
  class Territory < ::ActiveRecord::Base
    self.table_name = "not_risk_territories"

    belongs_to :game, class_name: "NotRisk::Game"
    belongs_to :owner, class_name: "NotRisk::Player", foreign_key: :owner_player_id, optional: true

    validates :territory_key, presence: true, uniqueness: { scope: :game_id }
    validates :armies, numericality: { greater_than_or_equal_to: 0 }
  end
end
