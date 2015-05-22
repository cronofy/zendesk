class TaskSynchronizer
  include Hatchet

  REMINDER_DURATION_SECONDS = 30 * 60

  class CronofyCredentialsInvalid < StandardError
    attr_reader :user_id

    def initialize(user_id)
      super("Cronofy credentials invalid for user=#{user_id}")
      @user_id = user_id
    end
  end

  class ZendeskCredentialsInvalid < StandardError
    attr_reader :user_id

    def initialize(user_id)
      super("Zendesk credentials invalid for user=#{user_id}")
      @user_id = user_id
    end
  end

  class StubAttributes
    def reminderTime
      nil
    end
  end

  ExpungedNote = Struct.new(:guid) do
    def title
      ""
    end

    def deleted
      true
    end

    def attributes
      @attributes ||= StubAttributes.new
    end
  end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def setup_sync(callback_url)
    log.info { "Entering #setup_sync - user=#{user.id}" }

    if ENV["CALLBACKS_ENABLED"].to_i > 0
      create_cronofy_notification_channel(callback_url)
    else
      log.info { "Callbacks not enabled - user=#{user.id}" }
    end

    # SyncRemindersFromZendesk.perform_later(user.id)
    # SyncRemindersFromCronofy.perform_later(user.id)

    log.info { "Exiting #setup_sync - user=#{user.id}" }
  end

  def writable_calendars
    log.info { "Entering #writable_calendars - user=#{user.id}" }

    calendars = cronofy_request do
      cronofy_client.list_calendars.reject(&:calendar_readonly)
    end

    log.info { "Exiting #writable_calendars - result=#{calendars.count} calendars -  user=#{user.id}" }

    calendars
  end

  def calendar_info(calendar_id)
    cronofy_request do
      cronofy_client.list_calendars.find { |calendar| calendar.calendar_id == calendar_id }
    end
  end

  def sync_changed_tasks
    log.info { "Entering #sync_changed_tasks - user=#{user.id}" }

    skip_deletes = user.first_zendesk_sync?

    sync_start = current_time

    log.info { "#sync_changed_tasks - user=#{user.id} - skip_deletes=#{skip_deletes}" }

    tasks = changed_tasks(user.zendesk_last_modified)

    tasks.each do |task|
      cronofy_request do
        update_event(task, skip_deletes: skip_deletes)
      end
    end

    user.zendesk_last_modified = sync_start
    user.save

    log.info { "Exiting #sync_changed_tasks - user=#{user.id}" }
  end

  def sync_changed_events
    log.info { "Entering #sync_changed_events - user=#{user.id}" }

    sync_start = current_time

    events = changed_events

    events.each do |event|
      evernote_request { update_zendesk_task_from_event(event) }
    end

    user.cronofy_last_modified = sync_start
    user.save

    log.info { "Exiting #sync_changed_events - user=#{user.id}" }
  end

  # private

  def create_cronofy_notification_channel(callback_url)
    cronofy_request do
      cronofy_client.create_channel(callback_url)
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

  def changed_tasks(last_modified=nil)
    tasks = []
    query = "type:ticket"
    query += " updated_at>=#{last_modified.strftime('%FT%T%:z')}" if last_modified

    log.debug { "#changed_tasks query=#{query}" }

    zendesk_client
      .search(query: query)
      .all do |ticket|
        tasks << ticket if ticket.type == 'task'
      end
    tasks
  end

  def update_evernote_reminder_from_event(event)
    cr_note = event_as_note(event)

    en_note = evernote_note_store.getNote(user.evernote_access_token, cr_note[:guid], false, false, false, false)
    en_note_changed = false

    if en_note.title != cr_note[:title]
      en_note.title = cr_note[:title]
      en_note_changed = true
    end

    if cr_note[:has_reminder]
      reminder_time = cr_note[:reminder_time].to_i * 1000

      if en_note.attributes.reminderTime != reminder_time
        en_note.attributes.reminderTime = reminder_time
        en_note_changed = true
      end
    else
      if en_note.attributes.reminderTime
        en_note.attributes.reminderTime = nil
        en_note.attributes.reminderOrder = nil
        en_note.attributes.reminderDoneTime = nil
        en_note_changed = true
      end
    end

    if en_note_changed
      evernote_note_store.updateNote(user.evernote_access_token, en_note)
    end
  end

  def update_event(task, opts = {})
    event = task_as_event(task)

    if event[:event_deleted]
      if opts.fetch(:skip_deletes, false)
        log.info { "#update_event Skipping deletion of #{event[:event_id]}" }
      else
        log.info { "#update_event Deleting #{event[:event_id]}" }
        cronofy_client.delete_event(user.cronofy_calendar_id, event[:event_id])
      end
    else
      log.info { "#update_event Upserting #{event[:event_id]}, #{event[:attributes]}" }
      cronofy_client.upsert_event(user.cronofy_calendar_id, event[:attributes])
    end
  end

  def event_as_task(event)
    {
      id: event.event_id,
      summary: event.summary,
      has_reminder: !event.deleted,
      due_at: event.start.to_time.getutc,
    }
  end

  def task_as_event(task)
    event_deleted = task.due_at.nil?

    hash = {
      event_id: task.id,
      event_deleted: event_deleted,
    }

    unless event_deleted
      task_url = shorten_url("https://#{user.zendesk_subdomain}.zendesk.com/requests/#{task.id}")

      hash[:attributes] = {
        event_id: task.id,
        summary: task.subject,
        description: "#{task_url}\n\n#{task.description}",
      }

      if reminder_time = task.due_at
        log.debug { "reminder_time=#{reminder_time} (#{reminder_time.class})" }

        hash[:attributes][:start] = reminder_time
        hash[:attributes][:end] = reminder_time + REMINDER_DURATION_SECONDS
      end
    end

    hash
  end

  # Wrapper for Cronofy API requests to handle refreshing the access token
  def cronofy_request(&block)
    if user.cronofy_access_token_expired?(current_time)
      log.info { "#cronofy_request pre-emptively refreshing expired token" }
      refresh_cronofy_access_token
    end

    begin
      block.call
    rescue Cronofy::AuthenticationFailureError
      log.info { "#cronofy_request attempting to refresh token - user=#{user.id}" }
      refresh_cronofy_access_token
      block.call
    end
  rescue Cronofy::AuthenticationFailureError => e
    log.warn "#cronofy_request failed - user=#{user.id} - #{e.class} - #{e.message}", e
    raise CronofyCredentialsInvalid.new(user.id)
  rescue => e
    log.error "#cronofy_request failed - user=#{user.id} - #{e.class} - #{e.message}", e
    raise
  end

  def refresh_cronofy_access_token
    credentials = cronofy_client.refresh_access_token

    user.cronofy_access_token = credentials.access_token
    user.cronofy_refresh_token = credentials.refresh_token
    user.cronofy_access_token_expiration = Time.at(credentials.expires_at).getutc

    user.save
  rescue Cronofy::BadRequestError => e
    log.warn "#refresh_cronofy_access_token failed - user=#{user.id} - #{e.class} - #{e.message}", e
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
    @zendesk_client ||= ZendeskAPI::Client.new do |config|
      config.url = "https://#{user.zendesk_subdomain}.zendesk.com/api/v2"
      config.access_token = user.zendesk_access_token
    end
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
