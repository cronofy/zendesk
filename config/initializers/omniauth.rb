Rails.application.config.middleware.use OmniAuth::Builder do
  provider :cronofy, ENV["CRONOFY_CLIENT_ID"], ENV["CRONOFY_CLIENT_SECRET"], {
    scope: "read_account list_calendars create_event delete_event"
  }

  evernote_site = ENV['EVERNOTE_SITE'] || "https://www.evernote.com"
  provider :evernote, ENV['EVERNOTE_KEY'], ENV['EVERNOTE_SECRET'], client_options: { site: evernote_site }
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
