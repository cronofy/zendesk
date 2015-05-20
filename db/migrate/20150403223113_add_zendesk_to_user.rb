class AddZendeskToUser < ActiveRecord::Migration
  def change
    add_column :users, :zendesk_user_id, :string
    add_column :users, :zendesk_access_token, :string
  end
end
