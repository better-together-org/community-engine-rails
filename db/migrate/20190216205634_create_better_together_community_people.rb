class CreateBetterTogetherCommunityPeople < ActiveRecord::Migration[5.2]
  def change
    create_table :better_together_community_people do |t|
      t.string :given_name,
               null: false,
               limit: 50,
               index: {
                name: 'by_given_name'
               }
      t.string :family_name,
               limit: 50,
               index: {
                name: 'by_family_name'
               }

      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end
  end
end
