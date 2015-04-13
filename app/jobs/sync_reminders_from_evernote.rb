class SyncRemindersFromEvernote < ActiveJob::Base
  include Hatchet

  queue_as :default

  def perform(user_id)
    log.info { "Entering #perform(user_id=#{user_id})" }

    user = User.find(user_id)
    synchronizer = ReminderSynchronizer.new(user)
    synchronizer.sync_changed_notes

    log.info { "Exiting #perform(user_id=#{user_id})" }
  rescue => e
    log.error "Error within #perform(user_id=#{user_id}) - #{e.message}", e
  end
end