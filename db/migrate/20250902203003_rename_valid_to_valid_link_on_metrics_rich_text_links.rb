# frozen_string_literal: true

# Migration to rename a legacy `valid` boolean column to `valid_link` on the
# better_together_metrics_rich_text_links table to avoid method name collisions
# with ActiveRecord predicate methods.
class RenameValidToValidLinkOnMetricsRichTextLinks < ActiveRecord::Migration[7.1]
  def change
    table = :better_together_metrics_rich_text_links
    return unless table_exists?(table) && column_exists?(table, :valid) && !column_exists?(table, :valid_link)

    rename_column table, :valid, :valid_link
  end
end
