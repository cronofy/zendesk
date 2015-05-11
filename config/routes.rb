Rails.application.routes.draw do
  root "root#show"

  post 'calendar', to: 'root#calendar'
  post 'reset', to: 'root#reset'
  post 'sync', to: 'root#sync'
  delete '/', to: 'root#destroy'

  post '/webhooks/cronofy/:id', to: 'cronofy_webhooks#inbound', as: 'cronofy_callback'
  get '/webhooks/evernote', to: 'evernote_webhooks#inbound', as: 'evernote_callback'

  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  resource :session

  match '*a', to: 'root#not_found', via: :all
  match '/',  to: 'root#not_found', via: :all
end
