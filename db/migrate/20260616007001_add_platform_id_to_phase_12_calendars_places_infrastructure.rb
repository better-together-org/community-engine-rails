# frozen_string_literal: true

# Phase 12 — Calendars, Places, Infrastructure (buildings, floors, rooms)
class AddPlatformIdToPhase12CalendarsPlacesInfrastructure < ActiveRecord::Migration[7.2]
  def change
    # Calendars & Places: community-scoped content, now platform-indexed
    %w[
      better_together_calendars
      better_together_places
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # Infrastructure hierarchy: buildings, floors, rooms
    %w[
      better_together_infrastructure_buildings
      better_together_infrastructure_floors
      better_together_infrastructure_rooms
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end
  end
end
