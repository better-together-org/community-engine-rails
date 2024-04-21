# frozen_string_literal: true

# Creates roles table
class CreateBetterTogetherRoles < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :roles do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_position

      t.string :slug, null: false, index: { unique: true }
      t.string :resource_class, null: false

      # Add a composite unique index on resource_class and position
      t.index %i[resource_class position], unique: true, name: 'index_roles_on_resource_class_and_position'
    end
  end
end
