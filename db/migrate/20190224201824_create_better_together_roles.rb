# frozen_string_literal: true

# Creates roles table
class CreateBetterTogetherRoles < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :roles do |t|
      t.bt_identifier
      t.bt_protected
      t.integer :position, null: false
      t.string :slug, null: false, index: { unique: true }
      t.string :target_class, null: false

      # Add a composite unique index on target_class and sort_order
      t.index %i[target_class position], unique: true, name: 'index_roles_on_target_class_and_position'
    end
  end
end
