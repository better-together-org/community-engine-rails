# frozen_string_literal: true

# Phase 4 — Report isolation.
# Reports are moderation artifacts; platform admins should only see reports
# from their own platform context. Nullable; backfill to host platform.
class AddPlatformIdToReports < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_reports, :platform_id)

    add_reference :better_together_reports, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
