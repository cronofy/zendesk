class RootController < ApplicationController
  def show
  end

  def calendar
    if logged_in?
      current_user.set_cronofy_calendar_id(params[:calendar_id])
      current_user.save(current_user)
      flash[:info] = "Calendar ID set"
    else
      flash[:alert] = "Must be connected to your calendar account before we do that"
    end

    redirect_to :root
  end

  def reset
    if logged_in?
      current_user.cronofy_calendar_id = nil
      current_user.evernote_high_usn = 0
      current_user.save(current_user)

      flash[:info] = "Syncing reset"
    else
      flash[:alert] = "Must be connected to your calendar account before we do that"
    end

    redirect_to :root
  end

  def sync
    notes_as_events.each do |event|
      if event[:event_deleted]
        log.info { "Deleting #{event[:event_id]}" }
        cronofy_client.delete_event(current_user.cronofy_calendar_id, event[:event_id])
      else
        log.info { "Upserting #{event[:event_id]}" }
        cronofy_client.upsert_event(current_user.cronofy_calendar_id, event[:attributes])
      end
    end

    current_user.evernote_high_usn = self.evernote_high_usn
    current_user.save

    flash[:info] = "Synced #{notes.count} notes"

    redirect_to :root
  end

  def notes
    return @notes if @notes

    note_filter = Evernote::EDAM::NoteStore::NoteFilter.new

    filter = Evernote::EDAM::NoteStore::SyncChunkFilter.new
    filter.includeNotes = true
    filter.includeNoteAttributes = true
    filter.includeExpunged = true

    @notes = []
    @sync_chunks = 0

    highest_usn = -1
    max_entries = 100

    until self.evernote_high_usn == highest_usn
      @sync_chunk = evernote_note_store.getFilteredSyncChunk(current_user.evernote_access_token, self.evernote_high_usn, max_entries, filter)
      @sync_chunks += 1

      @notes.concat(@sync_chunk.notes)         if @sync_chunk.notes
      @notes.concat(@sync_chunk.expungedNotes) if @sync_chunk.expungedNotes

      self.evernote_high_usn = @sync_chunk.chunkHighUSN
      highest_usn = @sync_chunk.updateCount
    end

    @notes
  end

  def evernote_high_usn
    @evernote_high_usn ||= current_user.evernote_high_usn
  end

  def evernote_high_usn=(value)
    @evernote_high_usn = value
  end

  REMINDER_DURATION_SECONDS = 10 * 60

  def notes_as_events
    notes.map do |note|
      event_deleted = (!!note.deleted or note.attributes.reminderTime.nil?)

      hash = {
        event_id: note.guid,
        event_deleted: event_deleted,
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
  end

  attr_reader :sync_chunk
  attr_reader :sync_chunks

  helper_method :notes, :sync_chunk, :sync_chunks, :notes_as_events

  def calendars
    @calendars ||= cronofy_client.list_calendars["calendars"]
  end

  helper_method :calendars

  def writable_calendars
    calendars.reject { |c| c["calendar_readonly"] }
  end

  helper_method :writable_calendars

  def grouped_calendars
    @grouped_calendars ||= begin
      writable_calendars
        .map { |c| [ c["calendar_name"], "#{c["profile_name"]} [#{c["provider_name"].titlecase}]", c["calendar_id"] ] }
        .sort_by { |c| [c[1], c[0].downcase] }
        .group_by { |c| c[1] }
    end
  end

  helper_method :grouped_calendars

  def evernote_client
    @evernote_client ||= EvernoteOAuth::Client.new(token: current_user.evernote_access_token)
  end

  def evernote_note_store
    @evernote_note_store ||= evernote_client.note_store
  end

  def cronofy_client
    @cronofy_client ||= Cronofy::Client.new(
      ENV["CRONOFY_CLIENT_ID"],
      ENV["CRONOFY_CLIENT_SECRET"],
      current_user.cronofy_access_token,
      current_user.cronofy_refresh_token
    )
  end

  # Wrapper for API requests to handle refreshing the access token when it's expired
  def api_request(&block)
    begin
      if current_user.cronofy_access_token_expired?(current_time)
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
    current_user.cronofy_access_token = credentials.access_token
    current_user.cronofy_refresh_token = credentials.refresh_token
    current_user.cronofy_access_token_expiration = credentials.expires_at
    current_user.save
  end
end
