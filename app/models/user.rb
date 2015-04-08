class User < ActiveRecord::Base
  include Hatchet

  def evernote_credentials?
    log.debug { "evernote_user_id=#{evernote_user_id}, evernote_access_token=#{evernote_access_token}" }
    !self.evernote_user_id.blank? && !self.evernote_access_token.blank?
  end

  def set_cronofy_calendar_id(calendar_id)
    raise "calendar_id required" if calendar_id.blank?

    self.cronofy_calendar_id = calendar_id
    self.evernote_high_usn = 0
  end

  def cronofy_access_token_expired?(time)
    cronofy_access_token_expiration.nil? or cronofy_access_token_expiration < time
  end
end
