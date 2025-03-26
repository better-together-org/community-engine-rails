# frozen_string_literal: true

# Cleans up unused columns on pages table
class RemoveUnusedColumnsFromBetterTogetherPages < ActiveRecord::Migration[7.1]
  def change
    remove_column :better_together_pages, :language  if column_exists?(:better_together_pages, :language)
    remove_column :better_together_pages, :published if column_exists?(:better_together_pages, :published)
  end
end
