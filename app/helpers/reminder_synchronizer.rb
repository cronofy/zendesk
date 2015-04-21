class ReminderSynchronizer
  include Hatchet

  REMINDER_DURATION_SECONDS = 30 * 60

  class CronofyCredentialsInvalid < StandardError
    attr_reader :user_id

    def initialize(user_id)
      super("Cronofy credentials invalid for user=#{user_id}")
      @user_id = user_id
    end
  end

  class EvernoteCredentialsInvalid < StandardError
    attr_reader :user_id

    def initialize(user_id)
      super("Evernote credentials invalid for user=#{user_id}")
      @user_id = user_id
    end
  end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def writable_calendars
    cronofy_request do
      cronofy_client.list_calendars.reject(&:calendar_readonly)
    end
  end

  def sync_changed_notes
    notes, highest_usn = evernote_request { changed_notes }

    notes.each do |note|
      cronofy_request do
        update_event(note)
      end
    end

    user.evernote_high_usn = highest_usn
    user.save
  end

  def create_cronofy_notification_channel(callback_url)
    cronofy_request do
      cronofy_client.create_channel(callback_url)
    end
  end

  def sync_changed_events
    sync_start = current_time

    events = changed_events

    events.each do |event|
      evernote_request { update_evernote_reminder_from_event(event) }
    end

    user.cronofy_last_modified = sync_start
    user.save
  end

  private

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

  def changed_notes
    note_filter = Evernote::EDAM::NoteStore::NoteFilter.new

    filter = Evernote::EDAM::NoteStore::SyncChunkFilter.new
    filter.includeNotes = true
    filter.includeNoteAttributes = true
    filter.includeExpunged = true

    notes = []

    highest_seen_usn = user.evernote_high_usn
    highest_usn = -1
    max_entries = 100

    until highest_seen_usn == highest_usn
      sync_chunk = evernote_note_store.getFilteredSyncChunk(user.evernote_access_token, highest_seen_usn, max_entries, filter)

      notes.concat(sync_chunk.notes)         if sync_chunk.notes
      notes.concat(sync_chunk.expungedNotes) if sync_chunk.expungedNotes

      highest_seen_usn = sync_chunk.chunkHighUSN
      highest_usn = sync_chunk.updateCount
    end

    [notes, highest_usn]
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

  def update_event(note)
    event = note_as_event(note)

    if event[:event_deleted]
      log.info { "Deleting #{event[:event_id]}" }
      cronofy_client.delete_event(user.cronofy_calendar_id, event[:event_id])
    else
      log.info { "Upserting #{event[:event_id]}" }
      cronofy_client.upsert_event(user.cronofy_calendar_id, event[:attributes])
    end
  end

  def event_as_note(event)
    {
      guid: event.event_id,
      title: event.summary,
      has_reminder: !event.deleted,
      reminder_time: event.start.to_time.getutc,
    }
  end

  def note_as_event(note)
    event_deleted = (!!note.deleted or note.attributes.reminderTime.nil?)

    note_url = evernote_client.endpoint("shard/#{evernote_user.shardId}/nl/#{evernote_user.id}/#{note.guid}/")

    hash = {
      event_id: note.guid,
      event_deleted: event_deleted,
      note_attributes: note.attributes.inspect,
      attributes: {
        event_id: note.guid,
        summary: note.title,
        description: note_url,
      },
    }

    if reminder_time = note.attributes.reminderTime
      log.debug { "reminder_time=#{reminder_time} (#{reminder_time.class})" }
      start_time = Time.at(reminder_time / 1000.0)
      log.debug { "start_time=#{start_time} (#{start_time.class})" }

      hash[:attributes][:start] = start_time
      hash[:attributes][:end] = start_time + REMINDER_DURATION_SECONDS
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

  # Wrapper for Evernote API requests to handle refreshing the access token
  def evernote_request(&block)
    block.call
  rescue Evernote::EDAM::Error::EDAMUserException => e
    error_desc = Evernote::EDAM::Error::EDAMErrorCode::VALUE_MAP.fetch(e.errorCode, "Unknown")

    if e.errorCode == Evernote::EDAM::Error::EDAMErrorCode::AUTH_EXPIRED
      log.warn "#evernote_request failed - user=#{user.id} - #{e.class} - errorCode=#{e.errorCode}, errorDesc=#{error_desc}", e
      raise EvernoteCredentialsInvalid.new(user.id)
    end

    log.error "#evernote_request failed - user=#{user.id} - #{e.class} - errorCode=#{e.errorCode}, errorDesc=#{error_desc}", e
    raise
  rescue => e
    log.error "#evernote_request failed - user=#{user.id} - #{e.class} - #{e.message}", e
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

  def evernote_client
    @evernote_client ||= EvernoteOAuth::Client.new(token: user.evernote_access_token)
  end

  def evernote_note_store
    @evernote_note_store ||= evernote_client.note_store
  end

  def evernote_user_store
    @evernote_user_store ||= evernote_client.user_store
  end

  def evernote_user
    @evernote_user ||= evernote_user_store.getUser(user.evernote_access_token)
  end

  def cronofy_client
    @cronofy_client ||= Cronofy::Client.new(
      access_token: user.cronofy_access_token,
      refresh_token: user.cronofy_refresh_token,
    )
  end
end
