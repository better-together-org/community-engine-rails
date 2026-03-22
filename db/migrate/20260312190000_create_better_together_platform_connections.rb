# frozen_string_literal: true

class CreateBetterTogetherPlatformConnections < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :platform_connections do |t|
      t.references :source_platform, null: false, type: :uuid,
                                     foreign_key: { to_table: :better_together_platforms }
      t.references :target_platform, null: false, type: :uuid,
                                     foreign_key: { to_table: :better_together_platforms }
      t.string :status, null: false, default: 'pending'
      t.string :connection_kind, null: false, default: 'peer'
      t.boolean :content_sharing_enabled, null: false, default: false
      t.boolean :federation_auth_enabled, null: false, default: false
      t.jsonb :settings, null: false, default: {}
    end

    add_index :better_together_platform_connections, %i[source_platform_id target_platform_id],
              unique: true,
              name: 'index_bt_platform_connections_on_source_and_target'
    add_index :better_together_platform_connections, :status
    add_index :better_together_platform_connections, :connection_kind
  end
end
