class EventTracker < ActiveRecord::Base

  OPERATION_UPDATE = 1
  OPERATION_DELETE = 2

  def self.delete_event?(user_id, event_id)
    if tracker = EventTracker.find_by(user_id: user_id, event_id: event_id)
      tracker.operation == OPERATION_UPDATE
    else
      true
    end
  end

  def self.track_delete(user_id, event_id)
    track_operation(user_id, event_id, OPERATION_DELETE)
  end

  def self.track_update(user_id, event_id)
    track_operation(user_id, event_id, OPERATION_UPDATE)
  end

  def self.track_operation(user_id, event_id, operation)
    tracker = begin
                EventTracker.find_or_create_by(user_id: user_id, event_id: event_id)
              rescue ActiveRecord::RecordNotUnique
                # small chance in concurrent calls that this could generate a collision
                EventTracker.find_by(user_id: user_id, event_id: event_id)
              end
    tracker.operation = operation
    tracker.save
  end
end
