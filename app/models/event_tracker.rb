class EventTracker < ActiveRecord::Base

  OPERATION_UPDATE = 1
  OPERATION_DELETE = 2

  def self.delete_event?(event_id)
    if tracker = EventTracker.find_by(event_id: event_id)
      tracker.operation == OPERATION_UPDATE
    else
      true
    end
  end

  def self.track_delete(event_id)
    track_operation(event_id, OPERATION_DELETE)
  end

  def self.track_update(event_id)
    track_operation(event_id, OPERATION_UPDATE)
  end

  def self.track_operation(event_id, operation)
    tracker = EventTracker.find_or_create_by(event_id: event_id)
    tracker.operation = operation
    tracker.save
  end
end
