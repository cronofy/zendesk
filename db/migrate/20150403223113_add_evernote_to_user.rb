class AddEvernoteToUser < ActiveRecord::Migration
  def change
    add_column :users, :evernote_user_id, :string
    add_column :users, :evernote_access_token, :string
  end
end
