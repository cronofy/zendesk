class CronofyWebhooksController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def inbound
    log.info { "#inbound - params=#{params.inspect}" }

    if params[:notification][:type] == "change"
      user = User.find_by(cronofy_id: params[:id])

      if user
        SyncRemindersFromCronofy.new.perform(user.id)
        render nothing: true, status: :ok
      else
        render nothing: true, status: :not_found
      end
    else
      render nothing: true, status: :ok
    end
  end
end
