# frozen_string_literal: true

class AddCreatorIdToBetterTogetherShortLinks < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_short_links)
    return if column_exists?(:better_together_short_links, :creator_id)

    add_column :better_together_short_links, :creator_id, :uuid
    add_index :better_together_short_links, :creator_id,
              name: 'index_better_together_short_links_on_creator_id'
  end
end
