class SyncMailChimpSubscriberWithUser < ActiveJob::Base
  include Hatchet

  @queue = :default

  def perform(user_id)

    log.info "#process started"
    unless mail_chimp_api_key
      log.warn { "No mail_chimp_api_key found" }
      return
    end

    unless user = User.find(user_id)
      log.warn { "Unable to find user=#{user.id}" }
      return
    end

    merge_vars = {}
    merge_vars['FNAME'] = user.first_name if user.first_name
    merge_vars['LNAME'] = user.last_name if user.last_name
    merge_vars['STATUS'] = generate_status(user)

    mail_chimp_client.lists.subscribe({
      id: list_id,
      email: { email: user.email },
      merge_vars: merge_vars,
      double_optin: false,
      update_existing: true
    })

    log.info { "Synchronised #{user.email} user=#{user.id} with MailChimp list #{list_id}" }
  rescue => e
    log.error "#perform error=#{e.message} for user=#{user.id} #{user.email}", e
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

  def generate_status(user)
    return 'active' if user.active?
    return 'zendesk_connected' if user.zendesk_credentials?
    return 'cronofy_connected' if user.cronofy_credentials?
    'none'
  end
end