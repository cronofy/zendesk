class User < ActiveRecord::Base
  include Hatchet

  def first_name
    name.split(" ", 2).first if name
  end

  def last_name
    name.split(" ", 2)[1] if name && name.split(" ", 2).length == 2
  end

  def self.remove_cronofy_credentials(id)
    log.debug { "Entering .remove_cronofy_credentials(id=#{id})" }
    user = User.find(id)

    user.cronofy_access_token = nil
    user.cronofy_refresh_token = nil
    user.cronofy_access_token_expiration = nil
    user.save

    log.debug { "Exiting .remove_cronofy_credentials(id=#{id})" }
    user
  end

  def self.remove_zendesk_credentials(id)
    log.debug { "Entering .remove_zendesk_credentials(id=#{id})" }
    user = User.find(id)

    user.zendesk_access_token = nil
    user.zendesk_subdomain = nil
    user.save

    log.debug { "Exiting .remove_zendesk_credentials(id=#{id})" }
    user
  end

  def active?
    all_credentials? and cronofy_calendar_id.present?
  end

  def all_credentials?
    cronofy_credentials? and zendesk_credentials?
  end

  def first_zendesk_sync?
    self.zendesk_last_modified.nil?
  end

  def cronofy_credentials?
    log.debug { "cronofy_id=#{cronofy_id}, cronofy_refresh_token=#{cronofy_refresh_token}" }
    !self.cronofy_id.blank? && !self.cronofy_refresh_token.blank?
  end

  def zendesk_credentials?
    log.debug { "zendesk_user_id=#{zendesk_user_id}, zendesk_access_token=#{zendesk_access_token}" }
    !self.zendesk_user_id.blank? && !self.zendesk_access_token.blank?
  end

  def set_cronofy_calendar_id(calendar_id)
    raise "calendar_id required" if calendar_id.blank?

    self.cronofy_calendar_id = calendar_id
    self.zendesk_last_modified = nil
  end

  def cronofy_access_token_expired?(time)
    cronofy_access_token_expiration.nil? or cronofy_access_token_expiration < time
  end

  def zendesk_sync_lock_set?(time)
    zendesk_sync_lock && zendesk_sync_lock > time
  end

  def admin?
    !!read_attribute(:is_admin)
  end

  def debug_enabled?
    read_attribute(:debug_enabled)
  end
end
