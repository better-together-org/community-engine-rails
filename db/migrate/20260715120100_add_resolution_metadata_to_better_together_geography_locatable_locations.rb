# frozen_string_literal: true

# Adds resolution provenance to LocatableLocation so it can also represent hierarchy
# placements (Settlement/Region/State/Country/Continent) resolved automatically by
# HierarchyResolutionJob, alongside its existing user-entered Address/Building/name rows.
# resolution_method/resolved_at stay nil for user-entered rows.
class AddResolutionMetadataToBetterTogetherGeographyLocatableLocations < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:better_together_geography_locatable_locations, :resolution_method)
      add_column :better_together_geography_locatable_locations, :resolution_method, :string
    end

    unless column_exists?(:better_together_geography_locatable_locations, :resolved_at)
      add_column :better_together_geography_locatable_locations, :resolved_at, :datetime
    end

    return if index_exists?(:better_together_geography_locatable_locations,
                            %i[locatable_type locatable_id location_type],
                            name: 'index_locatable_locations_on_locatable_and_location_type')

    add_index :better_together_geography_locatable_locations,
              %i[locatable_type locatable_id location_type],
              unique: true,
              name: 'index_locatable_locations_on_locatable_and_location_type'
  end
end
