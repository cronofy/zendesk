class AddZendeskTimeZoneToUser < ActiveRecord::Migration
  def change
    add_column :users, :zendesk_time_zone, :string
  end
end
