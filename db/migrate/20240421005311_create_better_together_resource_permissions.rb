class CreateBetterTogetherResourcePermissions < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :resource_permissions do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_position
      t.bt_resource_type
      t.bt_slug

      t.string :action, null: false
      t.string :target, null: false

      t.index %i[resource_type position], unique: true, name: 'index_resource_permissions_on_resource_type_and_position'
    end
  end
end
