class CreateBetterTogetherCommunities < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :communities do |t|
      t.bt_emoji_name index: { name: 'by_community_name'}
      t.bt_emoji_description index: { name: 'by_community_description'}

      # Reference to the better_together_people table for the creator
      t.bt_references :creator, null: false, index: { name: 'by_creator' }, target_table: :better_together_people

      # Adding privacy column
      t.string :privacy, null: false, default: 'public', limit: 50, index: { name: 'by_community_privacy' }

      # Standard columns like lock_version and timestamps are added by create_bt_table
    end
  end
end
