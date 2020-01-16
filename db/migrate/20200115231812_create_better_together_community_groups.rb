class CreateBetterTogetherCommunityGroups < ActiveRecord::Migration[5.2]
  def change
    create_table :better_together_community_groups do |t|
      t.string :bt_id,
               null: false,
               index: {
                 name: 'group_by_bt_id',
                 unique: true
               },
               limit: 50
      t.references :creator,
                    index: {
                      name: 'by_creator'
                    },
                    null: false
      t.string :group_privacy,
                index: {
                  name: 'by_group_privacy'
                },
                null: false,
                default: :public

      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end

    add_foreign_key :better_together_community_groups,
                    :better_together_community_people,
                    column: :creator_id

  end
end
