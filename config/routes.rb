Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :pictures do
    member do
      patch :replace
    end
  end
  resource :mastodon_profile, only: [:show, :edit, :update]
  resources :followers, only: [:index]
  resources :logs, only: [:index]

  get "up" => "rails/health#show", as: :rails_health_check

  root "pictures#index"
end
