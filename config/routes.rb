Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :pictures
  resource :mastodon_profile, only: [:show, :edit, :update]
  resources :followers, only: [:index]
  resources :logs, only: [:index]

  get "up" => "rails/health#show", as: :rails_health_check

  root "pictures#index"
end
