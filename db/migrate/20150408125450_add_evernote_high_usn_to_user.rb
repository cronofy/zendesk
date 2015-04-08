class AddEvernoteHighUsnToUser < ActiveRecord::Migration
  def change
    add_column :users, :evernote_high_usn, :integer, null: false, default: 0
  end
end
