class AddZendeskLastModifiedToUser < ActiveRecord::Migration
  def change
    add_column :users, :zendesk_last_modified, :datetime
  end
end
