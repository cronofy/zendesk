class AddUserIdToEventTracker < ActiveRecord::Migration
  def change
    drop_table :event_trackers

    create_table :event_trackers do |t|
      t.integer :user_id
      t.string :event_id
      t.integer :operation

      t.timestamps null: false
    end

    add_index :event_trackers, [:user_id, :event_id], { name: 'event_trackers_user_event_id', unique: true }

  end
end
