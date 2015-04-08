class AddCronofyLastModifiedToUser < ActiveRecord::Migration
  def change
    add_column :users, :cronofy_last_modified, :datetime
  end
end
