class CreateBetterTogetherCommunityGroups < ActiveRecord::Migration[5.2]
  def change
    create_table :better_together_community_groups do |t|
      t.string :bt_id,
               null: false,
               index: {
                name: 'group_by_bt_id',
                unique: true
               },
               limit: 20
      t.string :type,
               null: false
      t.string :name,
               null: false
      t.text :description,
              null: false
      t.string :slug,
                    null: false
      t.references :creator,
                    index: {
                      name: 'by_creator'
                    },
                    null: false
      t.string :privacy_level,
                    index: {
                      name: 'by_privacy_level'
                    },
                    null: false

      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end

    add_foreign_key :better_together_community_groups,
                    :better_together_community_people,
                    column: :creator_id

  end
end
