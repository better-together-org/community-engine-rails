# frozen_string_literal: true

# Creates roles table
class CreateBetterTogetherRoles < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :roles do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_position
      t.bt_resource_type
      t.bt_slug

      # Add a composite unique index on resource_type and position
      t.index %i[resource_type position], unique: true, name: 'index_roles_on_resource_type_and_position'
    end
  end
end
