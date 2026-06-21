# frozen_string_literal: true

class CreateBetterTogetherFleetNodeOwnerships < ActiveRecord::Migration[7.2]
  class FleetNode < ActiveRecord::Base
    self.table_name = 'better_together_fleet_nodes'
  end

  class FleetNodeOwnership < ActiveRecord::Base
    self.table_name = 'better_together_fleet_node_ownerships'
  end

  class Person < ActiveRecord::Base
    self.table_name = 'better_together_people'
  end

  def up
    create_node_ownerships_table
    backfill_node_ownerships
    remove_legacy_node_owner_columns
    remove_legacy_person_node_mapping
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'fleet node ownerships replace inline node owner columns and person node mappings'
  end

  private

  def create_node_ownerships_table
    return if table_exists?(:better_together_fleet_node_ownerships)

    create_bt_table :fleet_node_ownerships do |t|
      t.references :node,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_fleet_nodes, on_delete: :cascade },
                   index: { name: 'idx_bt_fleet_node_ownerships_node_id', unique: true }
      t.references :owner,
                   polymorphic: true,
                   type: :uuid,
                   null: false,
                   index: { name: 'idx_bt_fleet_node_ownerships_owner' }
    end
  end

  def backfill_node_ownerships
    backfill_inline_node_owners
    backfill_person_node_mappings
  end

  def backfill_inline_node_owners
    return unless column_exists?(:better_together_fleet_nodes, :owner_type) &&
                  column_exists?(:better_together_fleet_nodes, :owner_id)

    FleetNode.where.not(owner_type: nil, owner_id: nil).find_each do |node|
      FleetNodeOwnership.find_or_create_by!(node_id: node.id) do |ownership|
        ownership.owner_type = node.owner_type
        ownership.owner_id = node.owner_id
      end
    end
  end

  def backfill_person_node_mappings
    return unless column_exists?(:better_together_people, :borgberry_node_id)

    Person.where.not(borgberry_node_id: [nil, '']).find_each do |person|
      node = FleetNode.find_by(node_id: person.borgberry_node_id)
      next unless node

      FleetNodeOwnership.find_or_create_by!(node_id: node.id) do |ownership|
        ownership.owner_type = 'BetterTogether::Person'
        ownership.owner_id = person.id
      end
    end
  end

  def remove_legacy_node_owner_columns
    return unless column_exists?(:better_together_fleet_nodes, :owner_type) ||
                  column_exists?(:better_together_fleet_nodes, :owner_id)

    remove_reference :better_together_fleet_nodes, :owner, polymorphic: true
  end

  def remove_legacy_person_node_mapping
    return unless column_exists?(:better_together_people, :borgberry_node_id)

    remove_index :better_together_people, name: 'index_bt_people_on_borgberry_node_id' if index_name_exists?(
      :better_together_people, 'index_bt_people_on_borgberry_node_id'
    )
    remove_column :better_together_people, :borgberry_node_id
  end
end
