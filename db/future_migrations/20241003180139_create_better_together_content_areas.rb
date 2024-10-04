class CreateBetterTogetherContentAreas < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :areas, prefix: :better_together_content do |t|
      t.bt_creator
      t.bt_references :parent, null: false, target_table: :better_together_content_blocks
      t.bt_references :block, null: false, target_table: :better_together_content_blocks
      t.bt_position
      t.bt_privacy
      t.bt_visible

      t.string :type, null: false, default: 'BetterTogether::Content::Area'
    end
  end
end
