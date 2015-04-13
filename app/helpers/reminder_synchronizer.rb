class ReminderSynchronizer
  include Hatchet

  REMINDER_DURATION_SECONDS = 30 * 60

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def writable_calendars
    api_request do
      cronofy_client.list_calendars.reject(&:calendar_readonly)
    end
  end

  def sync_changed_notes
    notes, highest_usn = self.changed_notes

    notes.each do |note|
      update_event(note)
    end

    user.evernote_high_usn = highest_usn
    user.save
  end

  def create_cronofy_notification_channel(callback_url)
    api_request do
      cronofy_client.create_channel(callback_url)
    end
  end

  def sync_changed_events
    sync_start = current_time

    events = self.changed_events

    events.each do |event|
      update_evernote_reminder_from_event(event)
    end

    user.cronofy_last_modified = sync_start
    user.save
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

    api_request { cronofy_client.read_events(args).to_a }
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

  private

  def update_evernote_reminder_from_event(event)
    cr_note = event_as_note(event)

    en_note = evernote_note_store.getNote(user.evernote_access_token, cr_note[:guid], false, false, false, false)
    en_note_changed = false

    if en_note.title != cr_note[:title]
      en_note.title = cr_note[:title]
      en_note_changed = true
    end

    if cr_note[:has_reminder]
      if en_note.attributes.reminderTime != cr_note[:reminder_time].to_i * 1000
        en_note.attributes.reminderTime = cr_note[:reminder_time].to_i * 1000
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
      delete_event(event[:event_id])
    else
      upsert_event(event[:attributes])
    end
  end

  def delete_event(event_id)
    log.info { "Deleting #{event_id}" }

    api_request do
      cronofy_client.delete_event(user.cronofy_calendar_id, event_id)
    end
  end

  def upsert_event(event)
    log.info { "Upserting #{event[:event_id]}" }

    api_request do
      cronofy_client.upsert_event(user.cronofy_calendar_id, event)
    end
  end

  def event_as_note(event)
    {
      guid: event.event_id,
      title: event.summary,
      has_reminder: !event.deleted,
      reminder_time: event.start.to_time,
    }
  end

  def note_as_event(note)
    event_deleted = (!!note.deleted or note.attributes.reminderTime.nil?)

    hash = {
      event_id: note.guid,
      event_deleted: event_deleted,
      note_attributes: note.attributes.inspect,
      attributes: {
        event_id: note.guid,
        summary: note.title,
        description: "Note #{note.guid}",
      },
    }

    if reminder_time = note.attributes.reminderTime
      start_time = Time.at(reminder_time / 1000.0)

      hash[:attributes][:start] = start_time
      hash[:attributes][:end] = start_time + REMINDER_DURATION_SECONDS
    end

    hash
  end

  def evernote_client
    @evernote_client ||= EvernoteOAuth::Client.new(token: user.evernote_access_token)
  end

  def evernote_note_store
    @evernote_note_store ||= evernote_client.note_store
  end

  def cronofy_client
    @cronofy_client ||= Cronofy::Client.new(
      access_token: user.cronofy_access_token,
      refresh_token: user.cronofy_refresh_token,
    )
  end

  # Wrapper for API requests to handle refreshing the access token when it's expired
  def api_request(&block)
    begin
      if user.cronofy_access_token_expired?(current_time)
        log.info { "#api_request pre-emptively refreshing expired token" }
        refresh_user_access_token
      end

      block.call
    rescue Cronofy::AuthenticationFailureError
      log.info { "#api_request attempting to refresh token" }
      refresh_user_access_token
      block.call
    rescue => e
      log.error "#api_request failed with #{e.message}", e
      raise
    end
  end

  def refresh_user_access_token
    credentials = cronofy_client.refresh_access_token
    log.debug { credentials.to_hash }

    user.cronofy_access_token = credentials.access_token
    user.cronofy_refresh_token = credentials.refresh_token
    user.cronofy_access_token_expiration = Time.at(credentials.expires_at).getutc
    user.save
  end

  def current_time
    Time.now.getutc
  end
end
