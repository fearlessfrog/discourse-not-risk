# frozen_string_literal: true

class WidenNotRiskForeignKeys < ActiveRecord::Migration[7.0]
  def change
    change_column :not_risk_games, :topic_id, :bigint, null: false
    change_column :not_risk_games, :current_player_id, :bigint
    change_column :not_risk_games, :created_by_id, :bigint, null: false

    change_column :not_risk_players, :game_id, :bigint, null: false

    change_column :not_risk_territories, :game_id, :bigint, null: false
    change_column :not_risk_territories, :owner_player_id, :bigint

    change_column :not_risk_events, :game_id, :bigint, null: false
    change_column :not_risk_events, :player_id, :bigint
  end
end
