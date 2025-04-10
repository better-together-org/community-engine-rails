# frozen_string_literal: true

class AddTypeToBetterTogetherGeographyMaps < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_geography_maps, :type, :string, null: false, default: 'BetterTogether::Geography::Map'
  end
end
