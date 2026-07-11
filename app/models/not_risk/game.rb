# frozen_string_literal: true

module ::NotRisk
  class Game < ::ActiveRecord::Base
    self.table_name = "not_risk_games"

    belongs_to :topic, class_name: "::Topic"
    belongs_to :created_by, class_name: "::User"
    belongs_to :current_player, class_name: "NotRisk::Player", optional: true

    has_many :players, class_name: "NotRisk::Player", dependent: :destroy
    has_many :territories, class_name: "NotRisk::Territory", dependent: :destroy
    has_many :events, class_name: "NotRisk::Event", dependent: :destroy

    validates :name, :status, :current_phase, :map_key, presence: true
    validates :topic_id, uniqueness: true
  end
end
