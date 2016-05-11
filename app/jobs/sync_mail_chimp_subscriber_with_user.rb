class SyncMailChimpSubscriberWithUser < ActiveJob::Base
  include Hatchet
  include MailChimpHelper

  @queue = :default

  def perform(user_id)

    log.debug "#process started"
    unless mail_chimp_api_key
      log.warn { "No mail_chimp_api_key found" }
      return
    end

    unless user = User.find(user_id)
      log.warn { "Unable to find user=#{user.id}" }
      return
    end

    merge_fields = {}
    merge_fields['FNAME'] = user.first_name if user.first_name
    merge_fields['LNAME'] = user.last_name if user.last_name
    merge_fields['STATUS'] = generate_status(user)

    mail_chimp_client
      .lists(mail_chimp_list_id)
      .members(email_hash(user.email))
      .upsert({
        body: {
          email_address: user.email,
          status: "subscribed",
          merge_fields: merge_fields,
          interests: { mail_chimp_interest_id => true },
        },
      })

    log.info { "Synchronised #{user.email} user=#{user.id} with MailChimp list #{mail_chimp_list_id}" }
  rescue => e
    log.error "#perform error=#{e.message} for user=#{user.id} #{user.email}", e
  end

  def generate_status(user)
    return 'active' if user.active?
    return 'zendesk_connected' if user.zendesk_credentials?
    return 'cronofy_connected' if user.cronofy_credentials?
    'none'
  end
end