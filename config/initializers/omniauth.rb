Rails.application.config.middleware.use OmniAuth::Builder do
  provider :cronofy, ENV["CRONOFY_CLIENT_ID"], ENV["CRONOFY_CLIENT_SECRET"], {
    scope: "read_account list_calendars read_events create_event delete_event"
  }

  zendesk_site = ENV['ZENDESK_SITE'] || "https://cronofy.zendesk.com"
  provider :zendesk, ENV['ZENDESK_CLIENT_ID'], ENV['ZENDESK_CLIENT_SECRET'], {
    scope: "read write",
    client_options: { site: zendesk_site }
  }
end

class OmniAuthLogger
  include Hatchet

  [:debug, :info, :warn, :error, :fatal].each do |level|
    define_method(level) do |message|
      log.add(level, message)
    end
  end
end

OmniAuth.config.logger = OmniAuthLogger.new
