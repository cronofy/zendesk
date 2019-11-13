class UnsubscribeUserFromMailerlite < ActiveJob::Base
  include Hatchet
  include MailerliteHelper

  @queue = :default

  def perform(user_email)
    log.info { "#perform started" }

    unless mailerlite_api_key
      log.warn { "No mailerlite_api_key found" }
      return
    end

    mailerlite_client.delete_group_subscriber(mailerlite_group_id, user_email)

    log.info { "Unsubscribed #{user_email} from Mailerlite list #{mailerlite_group_id}" }
  rescue => e
    log.error "#perform error=#{e.message} for user_email=#{user_email}" , e
  end
end
