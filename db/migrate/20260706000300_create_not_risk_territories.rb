# frozen_string_literal: true

class CreateNotRiskTerritories < ActiveRecord::Migration[7.0]
  def change
    create_table :not_risk_territories do |t|
      t.integer :game_id, null: false
      t.string :territory_key, null: false
      t.integer :owner_player_id
      t.integer :armies, null: false, default: 0
      t.timestamps
    end

    add_index :not_risk_territories, :game_id
    add_index :not_risk_territories, :owner_player_id
    add_index :not_risk_territories, %i[game_id territory_key], unique: true
  end
end
