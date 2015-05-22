Rails.application.routes.draw do
  root "root#show"

  post 'calendar', to: 'root#calendar'
  post 'reset', to: 'root#reset'
  post 'sync', to: 'root#sync'
  post 'setup_zendesk', to: 'root#setup_zendesk'

  delete '/', to: 'root#destroy'

  post '/webhooks/cronofy/:id', to: 'cronofy_webhooks#inbound', as: 'cronofy_callback'
  post '/webhooks/zendesk/:group_id', to: 'zendesk_webhooks#inbound', as: 'zendesk_callback'

  get "/auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"

  resource :session

  match '*a', to: 'root#not_found', via: :all
  match '/',  to: 'root#not_found', via: :all
end
