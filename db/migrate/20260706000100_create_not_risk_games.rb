# frozen_string_literal: true

class CreateNotRiskGames < ActiveRecord::Migration[7.0]
  def change
    create_table :not_risk_games do |t|
      t.integer :topic_id, null: false
      t.string :name, null: false
      t.string :status, null: false, default: "setup"
      t.integer :current_player_id
      t.string :current_phase, null: false, default: "reinforce"
      t.integer :turn_number, null: false, default: 1
      t.string :map_key, null: false, default: "fantasy_12_risklike"
      t.jsonb :settings, null: false, default: {}
      t.integer :created_by_id, null: false
      t.timestamps
    end

    add_index :not_risk_games, :topic_id
    add_index :not_risk_games, :created_by_id
    add_index :not_risk_games, :current_player_id
  end
end
