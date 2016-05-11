module MailChimpHelper

  def mail_chimp_list_id
    ENV['MAILCHIMP_LIST_ID']
  end

  def mail_chimp_api_key
    ENV['MAILCHIMP_API_KEY']
  end

  def mail_chimp_interest_id
    ENV['MAILCHIMP_INTEREST_ID']
  end

  def mail_chimp_client
    Gibbon::Request.new(api_key: mail_chimp_api_key)
  end

  def email_hash(email)
    Digest::MD5.hexdigest(email.downcase)
  end

end