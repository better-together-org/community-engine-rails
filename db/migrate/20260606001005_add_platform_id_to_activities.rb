# frozen_string_literal: true

# Phase 5 — Activity isolation.
# Scopes PublicActivity audit log entries to the platform where they occurred.
# Nullable; backfill assigns host platform to pre-existing records.
class AddPlatformIdToActivities < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_activities)

    add_reference :better_together_activities, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
