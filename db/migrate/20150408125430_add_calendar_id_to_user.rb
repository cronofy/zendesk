class AddCalendarIdToUser < ActiveRecord::Migration
  def change
    add_column :users, :cronofy_calendar_id, :string
  end
end
