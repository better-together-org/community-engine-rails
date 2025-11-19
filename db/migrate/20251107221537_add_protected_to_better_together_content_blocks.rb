# frozen_string_literal: true

# Adds protected column to prevent deletion of platform-critical blocks
class AddProtectedToBetterTogetherContentBlocks < ActiveRecord::Migration[7.2]
  def change
    change_table :better_together_content_blocks, bulk: true, &:bt_protected
  end
end
