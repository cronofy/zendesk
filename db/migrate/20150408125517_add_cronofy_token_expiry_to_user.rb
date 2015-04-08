class AddCronofyTokenExpiryToUser < ActiveRecord::Migration
  def change
    add_column :users, :cronofy_access_token_expiration, :datetime
  end
end
