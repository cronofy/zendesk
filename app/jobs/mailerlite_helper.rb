module MailerliteHelper
  def mailerlite_api_key
    ENV['MAILERLITE_API_KEY']
  end

  def mailerlite_group_id
    ENV['MAILERLITE_GROUP_ID'].to_i
  end

  def mailerlite_client
    MailerLite::Client.new(api_key: mailerlite_api_key)
  end
end
