# frozen_string_literal: true

# Migration to add position and locale columns (and a unique index) to the
# better_together_metrics_rich_text_links table for ordering and locale-aware
# rich-text link tracking.
class AddPositionAndLocaleToRichTextLinks < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_metrics_rich_text_links, :position, :integer, null: false, default: 0
    add_column :better_together_metrics_rich_text_links, :locale, :string, limit: 5, null: false,
                                                                           default: I18n.default_locale

    add_index :better_together_metrics_rich_text_links, %i[rich_text_id position locale],
              name: 'idx_bt_rtl_on_rich_text_pos_loc', unique: true
  end
end
