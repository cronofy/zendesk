class TaskSynchronizer
  include Hatchet
  include ZendeskApiClient

  REMINDER_HOUR_OF_DAY = 8
  REMINDER_DURATION_SECONDS = 10 * 60

  class CronofyCredentialsInvalid < StandardError
    attr_reader :user_id

    def initialize(user_id)
      super("Cronofy credentials invalid for user=#{user_id}")
      @user_id = user_id
    end
  end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def debug_log_level
    if user && user.debug_enabled?
      :info
    else
      :debug
    end
  end

  def setup_sync(callback_url)
    log.add(debug_log_level) { "Entering #setup_sync - user=#{user.id}" }

    create_zendesk_notification_channel
    create_cronofy_notification_channel(callback_url)

    SyncUserTasksFromZendesk.perform_later(user.id)
    SyncTasksFromCronofy.perform_later(user.id)

    log.debug { "Exiting #setup_sync - user=#{user.id}" }
  end

  def writable_calendars
    cronofy_request do
      cronofy_client.list_calendars.reject(&:calendar_readonly)
    end
  end

  def calendar_info(calendar_id)
    cronofy_request do
      cronofy_client.list_calendars.find { |calendar| calendar.calendar_id == calendar_id }
    end
  end

  def sync_changed_tasks
    log.ndc.scope("zendesk_subdomain=#{user.zendesk_subdomain}", "user_id=#{user.id}") do

      log.debug { "Entering #sync_changed_tasks" }

      if user.cronofy_calendar_id.blank?
        log.info { "Not syncing changed tasks as cronofy_calendar_id is not set" }
        return
      end

      skip_deletes = user.first_zendesk_sync?

      sync_start = current_time

      log.debug { "#sync_changed_tasks - skip_deletes=#{skip_deletes}" }

      # subtract 60 secs to account for system clock differences between domains
      last_modified = user.zendesk_last_modified ? user.zendesk_last_modified - 60 : nil

      tickets = changed_tickets(last_modified)

      log.add(debug_log_level) { "#sync_changed_tasks - tickets.count=#{tickets.count}" }

      begin
        tickets.each do |ticket|
          cronofy_request do
            update_event(ticket, skip_deletes: skip_deletes)
          end
        end

        user.zendesk_last_modified = sync_start
        user.save
      rescue => original_error
        begin
          calendar = calendar_info(user.cronofy_calendar_id)

          if calendar.nil? || calendar.calendar_readonly
            log.error { "Cannot sync changed tasks as calendar=#{user.cronofy_calendar_id} is readonly - removing cronofy_calendar_id" }
            user.cronofy_calendar_id = nil
            user.save
          end
        rescue => e
          log.error "Failed to check calendar status - #{e.message}", e
        end

        raise original_error
      end

      log.debug { "Exiting #sync_changed_tasks" }
    end
  end

  def sync_changed_events
    log.ndc.scope("zendesk_subdomain=#{user.zendesk_subdomain}", "user_id=#{user.id}") do

      log.debug { "Entering #sync_changed_events" }

      sync_start = current_time

      events = changed_events

      log.add(debug_log_level) { "#sync_changed_events - events.count=#{events.count}" }

      events.each do |event|
        update_zendesk_task_from_event(event)
      end

      user.cronofy_last_modified = sync_start
      user.save

      log.debug { "Exiting #sync_changed_events" }

    end
  end

  # private

  def create_zendesk_notification_channel
    target_id = upsert_zendesk_target
    upsert_zendesk_trigger(target_id)
  end

  def upsert_zendesk_target

    target_url = "https://zendesk.cronofy.com/webhooks/zendesk/#{user.zendesk_subdomain}"
    target_id = nil

    zendesk_client.targets.all do |target|
      return target.id if target.target_url == target_url
    end

    target = zendesk_client.targets.create(
      type: "url_target",
      title: "Calendar Connector Target",
      target_url: target_url,
      attribute: "message",
      method: "post"
    )

    log.debug { "#upsert_zendesk_target target=#{target.inspect}" }

    unless target
      raise ZendeskApiClient::ZendeskAdminRequiredError.new(user.id, user.zendesk_subdomain, "create_target")
    end

    target.id
  end

  def upsert_zendesk_trigger(target_id)

    active_trigger = nil

    zendesk_client.triggers.all do |trigger|
      break if active_trigger = trigger.actions
                                  .select { |action| action.field == 'notification_target' }
                                  .find { |action| action.value[0] == target_id }
    end

    unless active_trigger
      trigger_attributes = {
        title: "Calendar",
        actions: [
          {
            field: "notification_target",
            value: [
                target_id,
                "Ticket {{ticket.id}}"
            ]
          }
        ],
        conditions: {
          all: [],
          any: [
            {
              field: "update_type",
              operator: "is",
              value: "Create"
            },
            {
              field: "update_type",
              operator: "is",
              value: "Change"
            }
          ]
        },
      }

      active_trigger = zendesk_client.triggers.create(trigger_attributes)
    end

    unless active_trigger
      raise ZendeskApiClient::ZendeskAdminRequiredError.new(user.id, user.zendesk_subdomain, "create_trigger")
    end

    active_trigger
  end

  def create_cronofy_notification_channel(callback_url)
    cronofy_request do
      cronofy_client.create_channel(callback_url, filters: { only_managed: true })
    end
  end

  def changed_events
    args = {
      tzid: "Etc/UTC",
      only_managed: true,
      include_deleted: true,
    }

    if user.cronofy_last_modified
      args[:last_modified] = user.cronofy_last_modified
    end

    cronofy_request { cronofy_client.read_events(args).to_a }
  end

  def changed_tickets(last_modified=nil)
    query = "type:ticket"
    query += " updated_at>=#{last_modified.strftime('%FT%T%:z')}" if last_modified

    log.debug { "#changed_tickets query=#{query}" }

    tickets = zendesk_client
                .search(query: query)
                .to_a

    log.debug { "#changed_tickets tickets.count=#{tickets.count}" }
    tickets
  end

  def update_zendesk_task_from_event(event)
    log.add(debug_log_level) { "#update_zendesk_task_from_event event=#{event}" }
    cronofy_task = event_as_task(event)

    log.add(debug_log_level) { "#update_zendesk_task_from_event cronofy_task=#{cronofy_task}" }

    ticket = zendesk_client.tickets.find(id: cronofy_task[:id])

    log.add(debug_log_level) { "#update_zendesk_task_from_event ticket=#{ticket}" }

    if !cronofy_task[:deleted]
      ticket.type = 'task'
      ticket.due_at = cronofy_task[:due_at]
    end

    ticket.save!
  rescue ZendeskAPI::Error::NetworkError => e
    log.error "#update_zendesk_task_from_event event_id=#{event[:event_id]} failed with #{e.message} body=#{e.response.body}", e
  rescue => e
    log.error "#update_zendesk_task_from_event event_id=#{event[:event_id]} failed with #{e.message}", e
  end

  def update_event(task, opts = {})
    event = task_as_event(task)

    attempts = 0

    begin
      attempts += 1

      if event[:event_deleted]
        if opts.fetch(:skip_deletes, false)
          log.add(debug_log_level) { "#update_event Skipping deletion of #{event[:event_id]}" }
        elsif !EventTracker.delete_event?(user.id, event[:event_id])
          log.add(debug_log_level) { "#update_event already tracked deletion of #{event[:event_id]}" }
        else
          log.add(debug_log_level) { "#update_event Deleting #{event[:event_id]}" }
          cronofy_client.delete_event(user.cronofy_calendar_id, event[:event_id])
          EventTracker.track_delete(user.id, event[:event_id])
        end
      else
        log.add(debug_log_level) { "#update_event Upserting #{event[:event_id]}, #{event[:attributes][:start]}, #{event[:attributes][:tzid]}" }
        cronofy_client.upsert_event(user.cronofy_calendar_id, event[:attributes])
        EventTracker.track_update(user.id, event[:event_id])
      end
    rescue Cronofy::InvalidRequestError
      log.warn { "Invalid request for user=#{user.id}, cronofy_id=#{user.cronofy_id} - assume due date out of bounds so ignoring" }
    rescue Cronofy::TooManyRequestsError
      log.warn { "Hit rate limit for user=#{user.id}, cronofy_id=#{user.cronofy_id} - attempt=#{attempts}" }
      raise unless attempts < 10
      sleep 15
      retry
    end
  end

  def event_as_task(event)
    # note due_at has to be specified as ISO 8601 string even though Zendesk client
    # returns as Time :)
    {
      id: event.event_id,
      deleted: event.deleted,
      due_at: event.start.to_time.getutc.strftime('%FT%T%:z'),
    }
  end

  def task_as_event(task)
    # Filtering tasks as a delete here because they can change
    # from a ticket to another category and deletes are no-ops if
    # nothing to be done
    #
    event_deleted = task.status == 'solved' ||
                    task.type != 'task' ||
                    task.due_at.nil? ||
                    task.assignee_id != user.zendesk_user_id.to_i

    hash = {
      event_id: task.id,
      event_deleted: event_deleted,
    }

    unless event_deleted
      task_url = shorten_url("https://#{user.zendesk_subdomain}.zendesk.com/requests/#{task.id}")

      task_summary = "##{task.id} #{task.subject}"
      task_summary += " [#{task.priority.capitalize}]" if task.priority

      hash[:attributes] = {
        event_id: task.id,
        summary: task_summary,
        description: "#{task_url}\n\n#{task.description[0, 2000]}",
      }

      if task.due_at
        if time_zone = Time.find_zone(user.zendesk_time_zone)
          reminder_time = time_zone
                            .local(task.due_at.year, task.due_at.month, task.due_at.day, REMINDER_HOUR_OF_DAY)

          hash[:attributes][:tzid] = time_zone.tzinfo.identifier
        else
          log.warn { "#task_as_event unable to load timezone for [#{user.zendesk_time_zone}]" }
          reminder_time = Time.utc(task.due_at.year, task.due_at.month, task.due_at.day, REMINDER_HOUR_OF_DAY)
        end

        hash[:attributes][:start] = reminder_time
        hash[:attributes][:end] = reminder_time + REMINDER_DURATION_SECONDS
      end
    end

    hash
  end

  # Wrapper for Cronofy API requests to handle refreshing the access token
  def cronofy_request(&block)
    if user.cronofy_access_token_expired?(current_time)
      log.debug { "#cronofy_request pre-emptively refreshing expired token" }
      refresh_cronofy_access_token
    end

    begin
      block.call
    rescue Cronofy::AuthenticationFailureError
      log.add(debug_log_level) { "#cronofy_request attempting to refresh token - user=#{user.id}" }
      refresh_cronofy_access_token
      block.call
    end
  rescue Cronofy::AuthenticationFailureError => e
    log.warn "#cronofy_request failed - user=#{user.id} - #{e.class} - #{e.message}"
    raise CronofyCredentialsInvalid.new(user.id)
  rescue => e
    log.error "#cronofy_request failed - user=#{user.id} - #{e.class} - #{e.message}"
    raise
  end

  def refresh_cronofy_access_token
    credentials = cronofy_client.refresh_access_token

    user.cronofy_access_token = credentials.access_token
    user.cronofy_refresh_token = credentials.refresh_token
    user.cronofy_access_token_expiration = Time.at(credentials.expires_at).getutc

    user.save
  rescue Cronofy::BadRequestError => e
    log.warn "#refresh_cronofy_access_token failed - user=#{user.id} - #{e.class} - #{e.message}"
    raise CronofyCredentialsInvalid.new(user.id)
  end

  def current_time
    Time.now.getutc
  end

  def cronofy_client
    @cronofy_client ||= Cronofy::Client.new(
      access_token: user.cronofy_access_token,
      refresh_token: user.cronofy_refresh_token,
    )
  end

  def zendesk_client
    @zendesk_client ||= get_zendesk_client(user)
  end

  def shorten_url(url)
    if Shortinator.configured?
      Shortinator.shorten(url, 'zendesk')
    else
      url
    end
  rescue => e
    log.error "Failed to shorten url=#{url} - #{e.class} - #{e.message}", e
    url
  end
end
