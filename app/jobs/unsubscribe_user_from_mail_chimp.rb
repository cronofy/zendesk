class UnsubscribeUserFromMailChimp < ActiveJob::Base
  include Hatchet
  include MailChimpHelper

  @queue = :default

  def perform(user_email)

    log.debug "#perform started"
    unless mail_chimp_api_key
      log.warn { "No mail_chimp_api_key found" }
      return
    end

    mail_chimp_client
      .lists(mail_chimp_list_id)
      .members(email_hash(user_email))
      .update({
        body: {
          status: "unsubscribed",
        }
      })

    log.info { "Unsubscribed #{user_email} from MailChimp list #{mail_chimp_list_id}" }
  rescue => e
    log.error "#perform error=#{e.message} for user=#{user_email}", e
  end

end