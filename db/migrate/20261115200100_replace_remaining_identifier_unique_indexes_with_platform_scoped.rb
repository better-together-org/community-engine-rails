# frozen_string_literal: true

# Same change as the events migration for the other PlatformRecord tables that still carry a
# bare unique index on identifier. The Identifier concern already validates per platform.
class ReplaceRemainingIdentifierUniqueIndexesWithPlatformScoped < ActiveRecord::Migration[7.2]
  INDEXES = {
    better_together_calendars: 'idx_bt_calendars_on_identifier_platform_id',
    better_together_communities: 'idx_bt_communities_on_identifier_platform_id',
    better_together_people: 'idx_bt_people_on_identifier_platform_id',
    better_together_places: 'idx_bt_places_on_identifier_platform_id',
    better_together_geography_maps: 'idx_bt_geography_maps_on_identifier_platform_id',
    better_together_infrastructure_buildings: 'idx_bt_infra_buildings_on_identifier_platform_id',
    better_together_infrastructure_floors: 'idx_bt_infra_floors_on_identifier_platform_id',
    better_together_infrastructure_rooms: 'idx_bt_infra_rooms_on_identifier_platform_id'
  }.freeze

  def up
    INDEXES.each do |table, name|
      next unless table_exists?(table) && column_exists?(table, :platform_id)

      remove_index table, :identifier if index_exists?(table, :identifier, unique: true)
      next if index_name_exists?(table, name)

      add_index table, %i[identifier platform_id], unique: true, name: name, where: 'platform_id IS NOT NULL'
    end
  end

  def down
    INDEXES.each do |table, name|
      next unless table_exists?(table)

      remove_index table, name: name if index_name_exists?(table, name)
      add_index table, :identifier, unique: true unless index_exists?(table, :identifier, unique: true)
    end
  end
end
