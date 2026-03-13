# frozen_string_literal: true

class AddOauthCredentialsToBetterTogetherPlatformConnections < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_platform_connections, bulk: true do |t|
      t.string :oauth_client_id
      t.text :oauth_client_secret_ciphertext
    end

    add_index :better_together_platform_connections,
              :oauth_client_id,
              unique: true,
              name: 'index_bt_platform_connections_on_oauth_client_id'
  end
end
