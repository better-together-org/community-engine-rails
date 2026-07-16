# frozen_string_literal: true

# Phase 4 — Backfill platform_id for reports.
#
# Derived from the reported record's own platform first, falling back to the
# host platform only when the reportable type isn't one of the known content
# types or its platform_id isn't yet populated.
class BackfillPlatformIdForReports < ActiveRecord::Migration[7.2]
  REPORTABLE_TYPES = {
    'BetterTogether::Post' => 'better_together_posts',
    'BetterTogether::Page' => 'better_together_pages',
    'BetterTogether::Event' => 'better_together_events'
  }.freeze

  def up
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    REPORTABLE_TYPES.each do |type, owner_table|
      next unless table_exists?(owner_table)

      execute <<~SQL
        UPDATE better_together_reports r
        SET    platform_id = owner.platform_id
        FROM   #{owner_table} owner
        WHERE  r.reportable_type = #{quote(type)}
          AND  r.reportable_id = owner.id
          AND  r.platform_id IS NULL
          AND  owner.platform_id IS NOT NULL
      SQL
    end

    execute <<~SQL
      UPDATE better_together_reports
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end

  def down
    execute "UPDATE better_together_reports SET platform_id = NULL"
  end
end
