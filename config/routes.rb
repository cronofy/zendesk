Rails.application.routes.draw do
  root "root#show"

  post 'calendar', to: 'root#calendar'
  post 'reset', to: 'root#reset'
  post 'sync', to: 'root#sync'
  delete '/', to: 'root#destroy'

  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  resource :session
end
