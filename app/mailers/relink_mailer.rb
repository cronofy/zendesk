class RelinkMailer < ActionMailer::Base
  include Hatchet

  layout 'mail'

  default from: "Zendesk Calendar Connector <#{ENV["FROM_EMAIL_ADDRESS"] || "bot@cronofy.com"}>"

  def relink_cronofy(user_id)
    user = User.find(user_id)

    @url = root_url(relink: true, provider: "cronofy")

    mail to: user.email,
      subject: "Reconnect your calendar account"
  end

  def relink_zendesk(user_id)
    user = User.find(user_id)

    @url = root_url(relink: true, provider: "zendesk")

    mail to: user.email,
      subject: "Reconnect your Zendesk account"
  end
end
