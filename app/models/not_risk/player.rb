# frozen_string_literal: true

module ::NotRisk
  class Player < ::ActiveRecord::Base
    self.table_name = "not_risk_players"

    belongs_to :game, class_name: "NotRisk::Game"
    belongs_to :user, class_name: "::User"

    has_many :territories, class_name: "NotRisk::Territory", foreign_key: :owner_player_id
    has_many :events, class_name: "NotRisk::Event"

    validates :color, :position, presence: true
    validates :user_id, uniqueness: { scope: :game_id }
    validates :position, uniqueness: { scope: :game_id }
  end
end
