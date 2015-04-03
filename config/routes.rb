Rails.application.routes.draw do
  root "root#show"

  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  resource :session
end
