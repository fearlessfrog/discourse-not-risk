# frozen_string_literal: true

class MakeNotRiskGameTopicUnique < ActiveRecord::Migration[7.0]
  def change
    remove_index :not_risk_games, :topic_id
    add_index :not_risk_games, :topic_id, unique: true
  end
end
