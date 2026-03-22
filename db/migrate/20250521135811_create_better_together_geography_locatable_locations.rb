# frozen_string_literal: true

# Join table between polymorphic locatable and polymorphic location
class CreateBetterTogetherGeographyLocatableLocations < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :locatable_locations, prefix: :better_together_geography do |t|
      t.bt_creator
      t.bt_references :location, polymorphic: true, null: true, index: { name: 'locatable_location_by_location' }
      t.bt_references :locatable, polymorphic: true, null: false, index: { name: 'locatable_location_by_locatable' }

      t.index %i[locatable_id locatable_type location_id location_type], name: 'locatable_locations'

      t.string :name, index: { name: 'locatable_location_by_name' }
    end
  end
end
