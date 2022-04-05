class SyncUserTasksFromZendesk < ActiveJob::Base
  include Hatchet

  queue_as :default

  def perform(user_id)
    log.debug { "Entering #perform(user_id=#{user_id})" }

    user = User.find_by_id(user_id)

    if user
      if user.all_credentials?
        if user.zendesk_sync_lock_set?(Time.now)
          retry_delay = 30.seconds
          log.debug { "Zendesk sync lock set until #{user.zendesk_sync_lock} for user_id=#{user.id} - retrying in #{retry_delay.to_i} seconds" }
          retry_job wait: retry_delay
        else
          sync_changed_tasks(user)
        end
      else
        log.debug { "Insufficient credentials to perform sync for user=#{user_id}" }
      end
    else
      log.warn { "No record found for user=#{user_id}" }
    end

    log.debug { "Exiting #perform(user_id=#{user_id})" }
  rescue TaskSynchronizer::CronofyCredentialsInvalid => e
    log.warn { "user_id=#{user_id} - #{e.class} - #{e.message}" }
    User.remove_cronofy_credentials(e.user_id)
    RelinkMailer.relink_cronofy(e.user_id).deliver_later
  rescue ZendeskApiClient::ZendeskCredentialsInvalid => e
    log.warn { "user_id=#{user_id} - #{e.class} - #{e.message}" }
    User.remove_zendesk_credentials(e.user_id)
    RelinkMailer.relink_zendesk(e.user_id).deliver_later
  rescue JSON::ParserError => e
    if e.message.include?('"error"=>"invalid_token"')
      log.warn { "user_id=#{user_id} - #{e.class} - #{e.message}" }
      User.remove_zendesk_credentials(user_id)
      RelinkMailer.relink_zendesk(user_id).deliver_later
    else
      log.error "Error within #perform(user_id=#{user_id}) - #{e.class} - #{e.message}", e
      raise
    end
  rescue => e
    log.error "Error within #perform(user_id=#{user_id}) - #{e.class} - #{e.message}", e
    raise
  end

  def sync_changed_tasks(user)
    user.zendesk_sync_lock = Time.now + 5.minutes
    user.save

    synchronizer = TaskSynchronizer.new(user)
    synchronizer.sync_changed_tasks
  ensure
    user.zendesk_sync_lock = nil
    user.save
  end
end
