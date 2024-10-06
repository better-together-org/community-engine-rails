class CreateBetterTogetherContentPlatformBlocks < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :platform_blocks, prefix: :better_together_content do |t|
      t.bt_references :platform, null: false, target_table: :better_together_platforms
      t.bt_references :block, null: false, target_table: :better_together_content_blocks
    end
  end
end
