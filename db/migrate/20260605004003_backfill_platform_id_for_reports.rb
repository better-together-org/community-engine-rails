# frozen_string_literal: true

# Phase 4 — Backfill platform_id for reports to host platform.
class BackfillPlatformIdForReports < ActiveRecord::Migration[7.2]
  def up
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    execute <<~SQL
      UPDATE better_together_reports
      SET    platform_id = '#{host_platform_id}'
      WHERE  platform_id IS NULL
    SQL
  end

  def down
    execute "UPDATE better_together_reports SET platform_id = NULL"
  end
end
