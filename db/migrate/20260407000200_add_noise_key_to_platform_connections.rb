# frozen_string_literal: true

class AddNoiseKeyToPlatformConnections < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_platform_connections)

    return if column_exists?(:better_together_platform_connections, :noise_public_key)

    add_column :better_together_platform_connections, :noise_public_key, :string
    add_column :better_together_platform_connections, :routing_allowed, :boolean, default: true, null: false

    add_index :better_together_platform_connections, :noise_public_key,
              unique: true,
              where: 'noise_public_key IS NOT NULL',
              name: 'index_bt_platform_connections_on_noise_public_key'
  end
end
