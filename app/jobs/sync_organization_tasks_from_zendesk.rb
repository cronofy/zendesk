class SyncOrganizationTasksFromZendesk < ActiveJob::Base
  include Hatchet

  queue_as :default

  def perform(organization_id)
    log.debug { "Entering #perform(organization_id=#{organization_id})" }

    User.where(zendesk_organization_id: organization_id).find_each do |user|
      SyncUserTasksFromZendesk.perform_later(user.id)
      log.debug { "#perform queued SyncUserTasksFromZendesk for user_id=#{user.id}" }
    end

    log.debug { "Exiting #perform(organization_id=#{organization_id})" }
  rescue => e
    log.error "Error within #perform(organization_id=#{organization_id}) - #{e.message}", e
    raise
  end
end
