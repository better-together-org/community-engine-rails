class CreateBetterTogetherNavigationItems < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :navigation_items do |t|
      t.bt_references :navigation_area, null: false
      t.string :title, null: false
      t.string :slug, null: false, index: { unique: true }
      t.string :url
      t.string :icon
      t.integer :position, null: false
      t.boolean :visible, null: false, default: true
      t.string :item_type, null: false

      t.bt_protected
      
      # Polymorphic association for linkable
      t.bt_references :linkable, polymorphic: true, index: { name: 'by_linkable' }, optional: true

      # t.timestamps and t.integer :lock_version are included in create_bt_table
    end

    add_index :better_together_navigation_items, [:navigation_area_id, :position], unique: true, name: 'navigation_items_area_position'
  end
end
