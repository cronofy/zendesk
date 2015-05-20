class ZendeskWebhooksController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def inbound
    log.info { "#inbound - params=#{params.inspect}" }
    user = User.find_by(zendesk_user_id: params[:userId])

    if user
      SyncRemindersFromZendesk.perform_later(user.id)
      render nothing: true, status: :ok
    else
      render nothing: true, status: :not_found
    end
  end
end
