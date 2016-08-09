class AddDebugEnabledToUser < ActiveRecord::Migration
  def change
    add_column :users, :debug_enabled, :boolean, default: false
  end
end
