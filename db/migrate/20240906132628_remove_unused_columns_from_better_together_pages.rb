class RemoveUnusedColumnsFromBetterTogetherPages < ActiveRecord::Migration[7.1]
  def change
    remove_column :better_together_pages, :language
    remove_column :better_together_pages, :published
  end
end
