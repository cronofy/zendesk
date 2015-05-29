module ZendeskApiClient

  class ZendeskCredentialsInvalid < StandardError
    attr_reader :user_id

    def initialize(user_id)
      super("Zendesk credentials invalid for user=#{user_id}")
      @user_id = user_id
    end
  end

  def get_zendesk_client(user)
    ZendeskAPI::Client.new do |config|
      config.url = "https://#{user.zendesk_subdomain}.zendesk.com/api/v2"
      config.access_token = user.zendesk_access_token
    end
  end

end