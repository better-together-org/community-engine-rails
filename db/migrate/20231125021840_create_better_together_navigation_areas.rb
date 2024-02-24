# frozen_string_literal: true

# Creates navigation items table
class CreateBetterTogetherNavigationAreas < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :navigation_areas do |t|
      t.string :name, null: false, unique: true
      t.string :style
      t.boolean :visible, null: false, default: true
      t.string :slug, null: false, index: { unique: true }
      # Polymorphic association for navigable
      t.references :navigable, polymorphic: true, index: { name: 'by_navigable' }
      t.bt_protected

      # No need for t.timestamps and t.integer :lock_version as they are included in create_bt_table
    end
  end
end
