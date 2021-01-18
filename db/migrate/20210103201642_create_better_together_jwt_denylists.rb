class CreateBetterTogetherJwtDenylists < ActiveRecord::Migration[6.0]
  def change
    create_table :better_together_jwt_denylists do |t|
      t.string :bt_id,
               limit: 100,
               index: {
                 name: 'jwt_denylist_by_bt_id',
                 unique: true
               },
               null: false
      t.string :jti
      t.datetime :exp

      t.timestamps
    end
    add_index :better_together_jwt_denylists, :jti
  end
end
