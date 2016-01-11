class UnsubscribeUserFromMailChimp < ActiveJob::Base
  include Hatchet

  @queue = :default

  def perform(user_email)

    log.debug "#perform started"
    unless mail_chimp_api_key
      log.warn { "No mail_chimp_api_key found" }
      return
    end

    mail_chimp_client.lists.unsubscribe({
      id: list_id,
      email: { email: user_email },
      delete_member: true,
      send_notify: true
    })

    log.info { "Unsubscribed #{user_email} from MailChimp list #{list_id}" }
  rescue => e
    log.error "#perform error=#{e.message} for user=#{user_email}", e
  end

  def list_id
    ENV['MAILCHIMP_LIST_ID']
  end

  def mail_chimp_api_key
    ENV['MAILCHIMP_API_KEY']
  end

  def mail_chimp_client
    Gibbon::API.new mail_chimp_api_key
  end
end