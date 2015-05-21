class AddZendeskSubdomainToUser < ActiveRecord::Migration
  def change
    add_column :users, :zendesk_subdomain, :text
  end
end
