# frozen_string_literal: true

class RemoveBetterTogetherCategoriesSlugColumn < ActiveRecord::Migration[7.1]
  def change
    remove_column :better_together_categories, :slug, :string
  end
end
