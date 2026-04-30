# frozen_string_literal: true

class CreateBetterTogetherFleetNodes < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_fleet_nodes)

    create_bt_table :fleet_nodes do |t|
      t.string :node_id, null: false
      t.string :node_category, null: false, default: 'cat1' # cat1, cat2, cat3

      # Network
      t.string :headscale_ip
      t.string :lan_ip
      t.integer :borgberry_port, default: 8790

      # Hardware capabilities (JSON snapshot)
      t.jsonb :hardware, null: false, default: {}
      t.jsonb :compute, null: false, default: {}
      t.jsonb :services, null: false, default: {}

      # Status
      t.string :safety_tier, default: 'T0'
      t.boolean :online, default: false, null: false
      t.datetime :last_seen_at
      t.datetime :registered_at

      # Associations
      t.references :owner, polymorphic: true, type: :uuid, index: { name: 'idx_bt_fleet_nodes_owner' }
      t.references :platform, type: :uuid, null: true,
                              foreign_key: { to_table: :better_together_platforms, on_delete: :nullify },
                              index: { name: 'idx_bt_fleet_nodes_platform' }
    end

    add_index :better_together_fleet_nodes, :node_id,
              unique: true, name: 'idx_bt_fleet_nodes_node_id'
    add_index :better_together_fleet_nodes, :online,
              name: 'idx_bt_fleet_nodes_online'
  end
end
