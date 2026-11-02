# frozen_string_literal: true

# A category can carry a colour (for example the chip colour of an event category).
class AddColorToBetterTogetherCategories < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:better_together_categories, :color)

    add_column :better_together_categories, :color, :string
  end
end
