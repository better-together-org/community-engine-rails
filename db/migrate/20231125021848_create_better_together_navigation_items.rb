# frozen_string_literal: true

# Creates navigation items table
class CreateBetterTogetherNavigationItems < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :navigation_items do |t|
      t.bt_identifier
      t.bt_position
      t.bt_protected
      t.bt_slug
      t.bt_visible

      t.bt_references :navigation_area, null: false
      t.bt_references :parent, target_table: :better_together_navigation_items, optional: true,
                               index: { name: 'by_nav_item_parent' }

      t.string :url
      t.string :icon
      t.string :item_type, null: false

      # Polymorphic association for linkable
      t.bt_references :linkable, polymorphic: true, index: { name: 'by_linkable' }, optional: true

      # t.timestamps and t.integer :lock_version are included in create_bt_table
    end

    add_index :better_together_navigation_items,
              %i[navigation_area_id parent_id position],
              unique: true,
              name: 'navigation_items_area_position'
  end
end
