class User < ActiveRecord::Base
  include Hatchet

  def evernote_credentials?
    log.debug { "evernote_user_id=#{evernote_user_id}, evernote_access_token=#{evernote_access_token}" }
    !self.evernote_user_id.blank? && !self.evernote_access_token.blank?
  end
end
