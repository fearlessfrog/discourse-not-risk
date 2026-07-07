# frozen_string_literal: true

class CreateNotRiskPlayers < ActiveRecord::Migration[7.0]
  def change
    create_table :not_risk_players do |t|
      t.integer :game_id, null: false
      t.integer :user_id, null: false
      t.string :color, null: false
      t.integer :position, null: false
      t.datetime :eliminated_at
      t.jsonb :cards, null: false, default: []
      t.timestamps
    end

    add_index :not_risk_players, :game_id
    add_index :not_risk_players, :user_id
    add_index :not_risk_players, %i[game_id user_id], unique: true
    add_index :not_risk_players, %i[game_id position], unique: true
  end
end
