class CreateBetterTogetherRoles < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :roles do |t|
      t.boolean :reserved, null: false, default: false, index: { name: 'by_reserved_state' }
      t.integer :sort_order
      t.string :target_class, limit: 100

      # Add a composite unique index on target_class and sort_order
      t.index %i[target_class sort_order], unique: true, name: 'index_roles_on_target_class_and_sort_order'
    end
  end
end
