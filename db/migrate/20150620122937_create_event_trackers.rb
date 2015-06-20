class CreateEventTrackers < ActiveRecord::Migration
  def change
    create_table :event_trackers do |t|
      t.string :event_id
      t.integer :operation

      t.timestamps null: false
    end

    add_index :event_trackers, :event_id, { name: 'event_trackers_event_id', unique: true }
  end
end
