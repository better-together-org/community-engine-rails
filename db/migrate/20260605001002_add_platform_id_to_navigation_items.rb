# frozen_string_literal: true

# Phase 1 — Navigation isolation (items).
#
# NavigationItems are children of NavigationAreas. Adding platform_id directly
# enables efficient per-platform item queries without always joining through
# navigation_areas. The backfill migration copies platform_id from the parent
# area so the two stay consistent.
class AddPlatformIdToNavigationItems < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_navigation_items, :platform_id)

    add_reference :better_together_navigation_items, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
