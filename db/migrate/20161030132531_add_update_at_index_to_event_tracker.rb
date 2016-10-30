class AddUpdateAtIndexToEventTracker < ActiveRecord::Migration
  def change
    add_index :event_trackers, :updated_at
  end
end
