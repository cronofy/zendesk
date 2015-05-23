class ZendeskWebhooksController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def inbound
    log.info { "#inbound - params=#{params.inspect}" }

    User.where(zendesk_subdomain: params[:group_id]).find_each do |user|
      SyncUserTasksFromZendesk.perform_later(user.id)
      log.info { "#inbound queued SyncUserTasksFromZendesk for user_id=#{user.id}" }
    end

    render nothing: true, status: :ok
  end
end
