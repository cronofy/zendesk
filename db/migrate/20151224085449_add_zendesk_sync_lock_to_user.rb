class AddZendeskSyncLockToUser < ActiveRecord::Migration
  def change
    add_column :users, :zendesk_sync_lock, :datetime
  end
end
