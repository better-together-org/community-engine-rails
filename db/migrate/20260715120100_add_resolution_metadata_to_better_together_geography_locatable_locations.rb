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

    log_duplicate_rows_pending_deletion

    # Dedup before adding the unique index below — nothing enforced uniqueness on
    # (locatable_type, locatable_id, location_type) prior to this migration, so any
    # environment could have pre-existing duplicate rows. Keep the most-recently-created
    # row per group (the newest is the most likely to reflect the current/authoritative
    # placement); delete the rest. Every row this deletes is logged first (see
    # #log_duplicate_rows_pending_deletion above) — this DELETE is otherwise silent and
    # irreversible.
    execute <<~SQL
      DELETE FROM better_together_geography_locatable_locations
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY locatable_type, locatable_id, location_type
                   ORDER BY created_at DESC, id DESC
                 ) AS rn
          FROM better_together_geography_locatable_locations
        ) ranked
        WHERE rn > 1
      )
    SQL

    add_index :better_together_geography_locatable_locations,
              %i[locatable_type locatable_id location_type],
              unique: true,
              name: 'index_locatable_locations_on_locatable_and_location_type'
  end

  private

  # Forensic trail for the DELETE above: every doomed row's identifying info (id,
  # locatable, location_type, created_at) goes to both migration output (`say`, visible
  # in the deploy log for whoever runs this migration) and Rails.logger.warn (durable,
  # searchable after the fact) before it's gone for good — a bad "keep the newest"
  # choice can otherwise never be traced or manually recovered from.
  def log_duplicate_rows_pending_deletion
    doomed = connection.select_all(<<~SQL)
      SELECT id, locatable_type, locatable_id, location_type, created_at
      FROM (
        SELECT id, locatable_type, locatable_id, location_type, created_at,
               ROW_NUMBER() OVER (
                 PARTITION BY locatable_type, locatable_id, location_type
                 ORDER BY created_at DESC, id DESC
               ) AS rn
        FROM better_together_geography_locatable_locations
      ) ranked
      WHERE rn > 1
    SQL

    return if doomed.empty?

    say "Deleting #{doomed.count} duplicate LocatableLocation row(s) to add a uniqueness " \
        'index below - keeping the newest per (locatable_type, locatable_id, location_type):'
    doomed.each do |row|
      line = "id=#{row['id']} locatable=#{row['locatable_type']}##{row['locatable_id']} " \
             "location_type=#{row['location_type']} created_at=#{row['created_at']}"
      say "  #{line}"
      Rails.logger.warn("AddResolutionMetadataToBetterTogetherGeographyLocatableLocations: #{line}")
    end
  end
end
