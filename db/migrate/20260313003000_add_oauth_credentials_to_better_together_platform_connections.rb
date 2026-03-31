# frozen_string_literal: true

class AddOauthCredentialsToBetterTogetherPlatformConnections < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_platform_connections, :oauth_client_id, :string unless column_exists?(:better_together_platform_connections,
                                                                                                      :oauth_client_id)
    add_column :better_together_platform_connections, :oauth_client_secret, :text unless column_exists?(:better_together_platform_connections,
                                                                                                        :oauth_client_secret)

    return if index_name_exists?(:better_together_platform_connections, 'index_bt_platform_connections_on_oauth_client_id')

    add_index :better_together_platform_connections,
              :oauth_client_id,
              unique: true,
              name: 'index_bt_platform_connections_on_oauth_client_id'
  end
end
