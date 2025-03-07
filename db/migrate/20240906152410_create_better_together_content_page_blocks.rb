# frozen_string_literal: true

# Created join table between pages and blocks
class CreateBetterTogetherContentPageBlocks < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :page_blocks, prefix: 'better_together_content' do |t|
      t.bt_references :page, null: false
      t.bt_references :block, null: false, table_prefix: 'better_together_content'
      t.bt_position
    end

    add_index :better_together_content_page_blocks, %i[page_id block_id], unique: true,
                                                                          name: 'content_page_blocks_on_page_and_block'
    add_index :better_together_content_page_blocks, %i[page_id block_id position],
              name: 'content_page_blocks_on_page_block_and_position'
  end
end
