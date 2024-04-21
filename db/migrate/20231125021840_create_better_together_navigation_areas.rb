# frozen_string_literal: true

# Creates navigation items table
class CreateBetterTogetherNavigationAreas < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :navigation_areas do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_slug
      t.bt_visible

      t.string :name, null: false, unique: true
      t.string :style

      # Polymorphic association for navigable
      t.references :navigable, polymorphic: true, index: { name: 'by_navigable' }

      # No need for t.timestamps and t.integer :lock_version as they are included in create_bt_table
    end
  end
end
