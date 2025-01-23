# frozen_string_literal: true

class AddIconToBetterTogetherCategories < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    add_column :better_together_categories, :icon, :string, null: false, default: 'fas fa-icons'
  end
end
