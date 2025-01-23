# frozen_string_literal: true

# rubocop:todo Style/Documentation
class AddCreatorPrivacyAndVisibleColumnsToBetterTogetherContentBlocks < ActiveRecord::Migration[7.1]
  # rubocop:enable Style/Documentation
  def change
    change_table :better_together_content_blocks do |t|
      t.bt_creator
      t.bt_privacy
      t.bt_visible

      t.jsonb :content_area_settings, null: false, default: {}
    end
  end
end
