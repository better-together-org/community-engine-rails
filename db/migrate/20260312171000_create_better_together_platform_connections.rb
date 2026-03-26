# frozen_string_literal: true

# Creates the platform connections table for federation between BetterTogether instances.
# A connection represents a directed trust relationship between two platforms, enabling
# content sharing, federated auth, and other cross-instance collaboration features.
class CreateBetterTogetherPlatformConnections < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:better_together_platform_connections)
      create_bt_table :platform_connections do |t|
        t.bt_references :source_platform, target_table: :better_together_platforms,
                                          index: { name: 'idx_on_source_platform_id_bed3ccb00c' }
        t.bt_references :target_platform, target_table: :better_together_platforms,
                                          index: { name: 'idx_on_target_platform_id_24cfb3a8bf' }
        t.string  :status,                    default: 'pending', null: false
        t.string  :connection_kind,           default: 'peer',    null: false
        t.boolean :content_sharing_enabled,   default: false,     null: false
        t.boolean :federation_auth_enabled,   default: false,     null: false
        t.jsonb   :settings,                  default: {},        null: false
        t.string  :oauth_client_id
        t.text    :oauth_client_secret_ciphertext
      end
    end

    unless index_name_exists?(:better_together_platform_connections,
                              'index_better_together_platform_connections_on_connection_kind')
      add_index :better_together_platform_connections, :connection_kind,
                name: 'index_better_together_platform_connections_on_connection_kind'
    end
    unless index_name_exists?(:better_together_platform_connections,
                              'index_bt_platform_connections_on_oauth_client_id')
      add_index :better_together_platform_connections, :oauth_client_id,
                unique: true, name: 'index_bt_platform_connections_on_oauth_client_id'
    end
    unless index_name_exists?(:better_together_platform_connections,
                              'index_bt_platform_connections_on_source_and_target')
      add_index :better_together_platform_connections, %i[source_platform_id target_platform_id],
                unique: true, name: 'index_bt_platform_connections_on_source_and_target'
    end
    unless index_name_exists?(:better_together_platform_connections,
                              'index_better_together_platform_connections_on_status')
      add_index :better_together_platform_connections, :status,
                name: 'index_better_together_platform_connections_on_status'
    end
    # bt_references :source_platform and :target_platform already add FKs to
    # better_together_platforms via create_bt_table; no explicit add_foreign_key needed.
  end
end
