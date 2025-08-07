# frozen_string_literal: true

# Adds support for Single Table Inheritance (STI) to the
# BetterTogether::Geography::Map model by adding a `type` column.
# This allows for different subclasses of the model to be stored in the same table.
# The default value is set to 'BetterTogether::Geography::Map'.
#
# @see https://guides.rubyonrails.org/active_record_basics.html#single-table-inheritance
class AddTypeToBetterTogetherGeographyMaps < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_geography_maps, :type, :string, null: false, default: 'BetterTogether::Geography::Map'
  end
end
