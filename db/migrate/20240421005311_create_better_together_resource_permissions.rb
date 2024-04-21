class CreateBetterTogetherResourcePermissions < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :resource_permissions do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_position

      t.string :action, null: false
      t.string :resource_class, null: false
      t.string :slug, null: false, index: { unique: true }
    end
  end
end
