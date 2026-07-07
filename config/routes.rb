# frozen_string_literal: true

NotRisk::Engine.routes.draw do
  resources :games, only: %i[show create] do
    member do
      post :join
      post :start
      post :deploy
      post :attack
      post :advance_to_fortify
      post :fortify
      post :end_turn
    end
  end
end
