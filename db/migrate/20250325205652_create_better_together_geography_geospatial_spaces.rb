# frozen_string_literal: true

class CreateBetterTogetherGeographyGeospatialSpaces < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :geospatial_spaces, prefix: :better_together_geography do |t|
      t.bt_references :geospatial, polymorphic: true
      t.bt_position
      t.bt_primary_flag parent_key: :geospatial_id, index_base: :geospatial_spaces
      t.bt_references :space, target_table: :better_together_geography_spaces
    end
  end
end
