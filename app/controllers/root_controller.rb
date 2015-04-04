class RootController < ApplicationController
  def show
    if current_user && current_user.evernote_credentials?
      note_filter = Evernote::EDAM::NoteStore::NoteFilter.new

      filter = Evernote::EDAM::NoteStore::SyncChunkFilter.new
      filter.includeNotes = true
      filter.includeNoteAttributes = true
      filter.includeExpunged = true

      after_usn = 0 # Get all the things
      max_entries = 100

      @sync_chunk = evernote_note_store.getFilteredSyncChunk(current_user.evernote_access_token, after_usn, max_entries, filter)
    end
  rescue => e
    log.error "Failure - #{e.class} - #{e.message}", e
    raise
  end

  def evernote_client
    @evernote_client ||= EvernoteOAuth::Client.new(token: current_user.evernote_access_token)
  end

  def evernote_note_store
    @evernote_note_store ||= evernote_client.note_store
  end
end
