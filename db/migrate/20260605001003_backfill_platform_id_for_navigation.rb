# frozen_string_literal: true

# Phase 1 — Backfill platform_id for navigation areas and items.
#
# All existing navigation areas are assigned to the host platform.
# Navigation items inherit platform_id from their parent area.
class BackfillPlatformIdForNavigation < ActiveRecord::Migration[7.2]
  def up
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    execute <<~SQL
      UPDATE better_together_navigation_areas
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL

    execute <<~SQL
      UPDATE better_together_navigation_items ni
      SET    platform_id = na.platform_id
      FROM   better_together_navigation_areas na
      WHERE  ni.navigation_area_id = na.id
        AND  ni.platform_id IS NULL
    SQL
  end

  def down
    execute "UPDATE better_together_navigation_areas SET platform_id = NULL"
    execute "UPDATE better_together_navigation_items  SET platform_id = NULL"
  end
end
