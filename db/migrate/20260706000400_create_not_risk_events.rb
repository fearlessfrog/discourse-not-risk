# frozen_string_literal: true

class CreateNotRiskEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :not_risk_events do |t|
      t.integer :game_id, null: false
      t.integer :player_id
      t.integer :turn_number, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :not_risk_events, :game_id
    add_index :not_risk_events, :player_id
    add_index :not_risk_events, %i[game_id turn_number]
  end
end
