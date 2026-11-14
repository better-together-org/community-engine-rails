# frozen_string_literal: true

# Phase 1 — Navigation isolation.
#
# NavigationArea previously had no platform scope — all platforms shared the
# same four areas by identifier. Adding platform_id lets each platform own
# its own header/footer/host/better-together navigation trees.
#
# Nullable to allow safe deploy before backfill runs. The companion backfill
# migration (20260605001003) assigns existing areas to the host platform and
# the NOT NULL constraint is added after that.
class AddPlatformIdToNavigationAreas < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_navigation_areas, :platform_id)

    add_reference :better_together_navigation_areas, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
