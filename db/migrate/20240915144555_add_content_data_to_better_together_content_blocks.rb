# frozen_string_literal: true

class AddContentDataToBetterTogetherContentBlocks < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    add_column :better_together_content_blocks, :content_data, :jsonb, default: {}
  end
end
