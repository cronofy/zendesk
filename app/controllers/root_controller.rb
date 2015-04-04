class RootController < ApplicationController
  def show
    if current_user && current_user.evernote_credentials?
      note_filter = Evernote::EDAM::NoteStore::NoteFilter.new

      filter = Evernote::EDAM::NoteStore::SyncChunkFilter.new
      filter.includeNotes = true
      filter.includeNoteAttributes = true
      filter.includeExpunged = true

      @notes = []
      @sync_chunks = 0

      saved_high_usn = 0
      highest_usn = -1
      max_entries = 100

      until saved_high_usn == highest_usn
        @sync_chunk = evernote_note_store.getFilteredSyncChunk(current_user.evernote_access_token, saved_high_usn, max_entries, filter)
        @sync_chunks += 1

        @notes.concat(@sync_chunk.notes)         if @sync_chunk.notes
        @notes.concat(@sync_chunk.expungedNotes) if @sync_chunk.expungedNotes

        saved_high_usn = @sync_chunk.chunkHighUSN
        highest_usn = @sync_chunk.updateCount
      end
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
