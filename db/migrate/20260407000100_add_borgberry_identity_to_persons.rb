# frozen_string_literal: true

class AddBorgberryIdentityToPersons < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:better_together_people, :borgberry_did)
      add_column :better_together_people, :borgberry_did, :string
    end

    unless column_exists?(:better_together_people, :borgberry_node_id)
      add_column :better_together_people, :borgberry_node_id, :string
    end

    unless index_name_exists?(:better_together_people, 'index_bt_people_on_borgberry_did')
      add_index :better_together_people, :borgberry_did,
                unique: true,
                where: 'borgberry_did IS NOT NULL',
                name: 'index_bt_people_on_borgberry_did'
    end

    return if index_name_exists?(:better_together_people, 'index_bt_people_on_borgberry_node_id')

    add_index :better_together_people, :borgberry_node_id,
              unique: true,
              where: 'borgberry_node_id IS NOT NULL',
              name: 'index_bt_people_on_borgberry_node_id'
  end
end
