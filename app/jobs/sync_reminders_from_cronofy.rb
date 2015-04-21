class SyncRemindersFromCronofy < ActiveJob::Base
  include Hatchet

  queue_as :default

  def perform(user_id)
    log.info { "Entering #perform(user_id=#{user_id})" }

    user = User.find(user_id)

    if user
      if user.all_credentials?
        synchronizer = ReminderSynchronizer.new(user)
        synchronizer.sync_changed_events
      else
        log.warn { "Insufficient crendentials to perform sync for user=#{user_id}" }
      end
    else
      log.warn { "No record found for user=#{user_id}" }
    end

    log.info { "Exiting #perform(user_id=#{user_id})" }
  rescue ReminderSynchronizer::CronofyCredentialsInvalid => e
    log.warn { "#{e.class} - #{e.message}" }
    User.remove_cronofy_credentials(e.user_id)
    RelinkMailer.relink_cronofy(e.user_id).deliver_later
  rescue ReminderSynchronizer::EvernoteCredentialsInvalid => e
    log.warn { "#{e.class} - #{e.message}" }
    User.remove_evernote_credentials(e.user_id)
    RelinkMailer.relink_evernote(e.user_id).deliver_later
  rescue => e
    log.error "Error within #perform(user_id=#{user_id}) - #{e.message}", e
    raise
  end
end
