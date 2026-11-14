# frozen_string_literal: true

# Phase 12 — Backfill calendars, places, infrastructure with platform_id
class BackfillPlatformIdForPhase12CalendarsPlacesInfrastructure < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  def up # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
    # Step 1: Calendars from community
    if column_exists?(:better_together_calendars, :platform_id)
      execute <<~SQL
        UPDATE better_together_calendars cal
        SET    platform_id = c.platform_id
        FROM   better_together_communities c
        WHERE  cal.community_id = c.id
          AND  cal.platform_id IS NULL
          AND  c.platform_id IS NOT NULL
      SQL
    end

    # Step 2: Places from community
    if column_exists?(:better_together_places, :platform_id)
      execute <<~SQL
        UPDATE better_together_places p
        SET    platform_id = c.platform_id
        FROM   better_together_communities c
        WHERE  p.community_id = c.id
          AND  p.platform_id IS NULL
          AND  c.platform_id IS NOT NULL
      SQL
    end

    # Step 3: Infrastructure buildings from community
    if column_exists?(:better_together_infrastructure_buildings, :platform_id)
      execute <<~SQL
        UPDATE better_together_infrastructure_buildings b
        SET    platform_id = c.platform_id
        FROM   better_together_communities c
        WHERE  b.community_id = c.id
          AND  b.platform_id IS NULL
          AND  c.platform_id IS NOT NULL
      SQL
    end

    # Step 4: Infrastructure floors from buildings (cascading)
    if column_exists?(:better_together_infrastructure_floors, :platform_id)
      execute <<~SQL
        UPDATE better_together_infrastructure_floors f
        SET    platform_id = b.platform_id
        FROM   better_together_infrastructure_buildings b
        WHERE  f.building_id = b.id
          AND  f.platform_id IS NULL
          AND  b.platform_id IS NOT NULL
      SQL
    end

    # Step 5: Infrastructure rooms from floors (cascading)
    if column_exists?(:better_together_infrastructure_rooms, :platform_id)
      execute <<~SQL
        UPDATE better_together_infrastructure_rooms r
        SET    platform_id = f.platform_id
        FROM   better_together_infrastructure_floors f
        WHERE  r.floor_id = f.id
          AND  r.platform_id IS NULL
          AND  f.platform_id IS NOT NULL
      SQL
    end

    # Step 6: Host platform fallback for any remaining nulls
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    %w[
      better_together_calendars
      better_together_places
      better_together_infrastructure_buildings
      better_together_infrastructure_floors
      better_together_infrastructure_rooms
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute <<~SQL
        UPDATE #{table} SET platform_id = #{quote(host_platform_id)}
        WHERE platform_id IS NULL
      SQL
    end
  end

  def down
    %w[
      better_together_calendars
      better_together_places
      better_together_infrastructure_buildings
      better_together_infrastructure_floors
      better_together_infrastructure_rooms
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
