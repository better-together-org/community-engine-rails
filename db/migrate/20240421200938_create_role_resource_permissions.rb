class CreateRoleResourcePermissions < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :role_resource_permissions do |t|
      t.bt_references :role, foreign_key: { to_table: 'better_together_roles' }, index: { name: 'role_resource_permissions_role' }, null: false
      t.bt_references :resource_permission, foreign_key: { to_table: 'better_together_resource_permissions' }, index: { name: 'role_resource_permissions_resource_permission' }, null: false
      t.index [:role_id, :resource_permission_id], unique: true, name: 'unique_role_resource_permission_index'
    end
  end
end
