class User < ActiveRecord::Base
  include Hatchet

  def self.remove_cronofy_credentials(id)
    log.info { "Entering .remove_cronofy_credentials(id=#{id})" }
    user = User.find(id)

    user.cronofy_access_token = nil
    user.cronofy_refresh_token = nil
    user.cronofy_access_token_expiration = nil
    user.save

    log.info { "Exiting .remove_cronofy_credentials(id=#{id})" }
    user
  end

  def self.remove_evernote_credentials(id)
    log.info { "Entering .remove_evernote_credentials(id=#{id})" }
    user = User.find(id)

    user.evernote_access_token = nil
    user.save

    log.info { "Exiting .remove_evernote_credentials(id=#{id})" }
    user
  end

  def active?
    all_credentials? and cronofy_calendar_id.present?
  end

  def all_credentials?
    cronofy_credentials? and evernote_credentials?
  end

  def cronofy_credentials?
    log.debug { "cronofy_id=#{cronofy_id}, cronofy_refresh_token=#{cronofy_refresh_token}" }
    !self.cronofy_id.blank? && !self.cronofy_refresh_token.blank?
  end

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
