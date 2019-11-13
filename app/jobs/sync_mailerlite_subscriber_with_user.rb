class SyncMailerliteSubscriberWithUser < ActiveJob::Base
  include Hatchet
  include MailerliteHelper

  @queue = :default

  def perform(user_id)
    log.info { "#process started" }

    unless mailerlite_api_key
      log.warn { "No mailerlite_api_key found" }
      return
    end

    unless user = User.find(user_id)
      log.warn { "Unable to find user_id=#{user.id}" }
      return
    end

    subscriber = {
      email: user.email,
    }
    subscriber[:name] = user.first_name if user.first_name
    subscriber[:last_name] = user.last_name if user.last_name

    mailerlite_client.create_group_subscriber(mailerlite_group_id, subscriber)

    log.info { "Synchronised #{user.email} user_id=#{user.id} with Mailerlite Group #{mailerlite_group_id}" }
  rescue => e
    log.error "#perform error=#{e.message} for user_id=#{user.id} #{user.email}", e
  end
end
