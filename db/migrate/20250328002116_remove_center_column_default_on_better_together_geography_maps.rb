# frozen_string_literal: true

# Removes column default for geography column that's breaking rubocop. Not needed anyway (set in model)
class RemoveCenterColumnDefaultOnBetterTogetherGeographyMaps < ActiveRecord::Migration[7.1]
  def change
    change_column_default(:better_together_geography_maps, :center, nil)
  end
end
