Rails.application.config.middleware.use OmniAuth::Builder do
  provider :cronofy, ENV["CRONOFY_CLIENT_ID"], ENV["CRONOFY_CLIENT_SECRET"], {
    scope: "read_account list_calendars read_events create_event delete_event"
  }

  provider :zendesk, ENV['ZENDESK_CLIENT_ID'], ENV['ZENDESK_CLIENT_SECRET'], {
    scope: "read write",
    setup: lambda{|env|
      env['omniauth.strategy'].options[:client_options].site = "https://#{env['rack.session']['zendesk_subdomain']}.zendesk.com"
    },
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
