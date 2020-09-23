class CreateBetterTogetherMemberships < ActiveRecord::Migration[6.0]
  def change
    create_table :better_together_memberships do |t|
      t.string :bt_id,
               null: false,
               index: {
                 name: 'membership_by_bt_id',
                 unique: true
               },
               limit: 50
      t.references :member,
                    null: false,
                    polymorphic: true,
                    index: {
                      name: 'membership_by_member'
                    }
      t.references :joinable,
                    null: false,
                    polymorphic: true,
                    index: {
                      name: 'membership_by_joinable'
                    }
      t.references :role,
                    index: {
                      name: 'membership_by_role'
                    }
      t.integer :lock_version
      t.timestamps null: false
    end



    add_foreign_key :better_together_memberships,
                    :better_together_roles,
                    column: :role_id
  end
end
