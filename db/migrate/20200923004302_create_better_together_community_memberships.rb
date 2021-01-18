class CreateBetterTogetherCommunityMemberships < ActiveRecord::Migration[6.0]
  def change
    create_table :better_together_community_memberships do |t|
      t.string :bt_id,
               null: false,
               index: {
                 name: 'community_membership_by_bt_id',
                 unique: true
               },
               limit: 50
      t.references :member,
                    null: false,
                    index: {
                      name: 'community_membership_by_member'
                    }
      t.references :community,
                    null: false,
                    index: {
                      name: 'community_membership_by_community'
                    }
      t.references :role,
                    null: false,
                    index: {
                      name: 'community_membership_by_role'
                    }
      t.integer :lock_version,
                null: false,
                default: 0
      t.timestamps null: false
    end

    add_foreign_key :better_together_community_memberships,
                    :better_together_people,
                    column: :member_id

    add_foreign_key :better_together_community_memberships,
                    :better_together_communities,
                    column: :community_id

    add_foreign_key :better_together_community_memberships,
                    :better_together_roles,
                    column: :role_id

    add_index :better_together_community_memberships,
              %i[community_id member_id role_id],
              unique: true,
              name: 'unique_community_membership_member_role'
  end
end
