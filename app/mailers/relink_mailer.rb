class RelinkMailer < ActionMailer::Base
  include Hatchet

  layout 'mail'

  default from: "Evernote Calendar Connector <#{ENV["FROM_EMAIL_ADDRESS"] || "bot@cronofy.com"}>"

  def relink_cronofy(user_id)
    user = User.find(user_id)

    @url = root_url(relink: true, provider: "cronofy")

    mail to: user.email,
      subject: "Reconnect your calendar account"
  end

  def relink_evernote(user_id)
    user = User.find(user_id)

    @url = root_url(relink: true, provider: "evernote")

    mail to: user.email,
      subject: "Reconnect your Evernote account"
  end
end
