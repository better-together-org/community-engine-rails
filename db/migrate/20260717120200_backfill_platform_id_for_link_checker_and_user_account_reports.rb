# frozen_string_literal: true

# LinkCheckerReport/UserAccountReport got platform_id from Phase 13's blanket
# host-default with no per-row derivation. Re-derives from creator's platform
# membership first (matching the backfill_from_creator pattern from
# 20260330172000_add_platform_and_logged_in_to_metrics.rb), host-fallback for
# rows with no creator (e.g. scheduled/system-generated reports).
class BackfillPlatformIdForLinkCheckerAndUserAccountReports < ActiveRecord::Migration[7.2]
  TABLES = %i[
    better_together_metrics_link_checker_reports
    better_together_metrics_user_account_reports
  ].freeze

  def up
    TABLES.each { |table| backfill_from_creator(table) }
  end

  def down
    # Corrective re-derivation has no meaningful inverse.
  end

  private

  def backfill_from_creator(table)
    return unless column_exists?(table, :platform_id)

    execute <<~SQL.squish
      UPDATE #{quote_table_name(table)} rec
      SET platform_id = ppm.joinable_id
      FROM better_together_people p
      JOIN better_together_person_platform_memberships ppm ON p.id = ppm.member_id
      WHERE rec.creator_id = p.id
        AND rec.platform_id IS NULL
        AND ppm.joinable_id IS NOT NULL
    SQL

    host_platform_id = execute(
      'SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1'
    ).first&.fetch('id')

    if host_platform_id
      execute <<~SQL
        UPDATE #{quote_table_name(table)}
        SET platform_id = #{quote(host_platform_id)}
        WHERE platform_id IS NULL
      SQL
    end

    remaining_null = execute(
      "SELECT count(*) FROM #{quote_table_name(table)} WHERE platform_id IS NULL"
    ).first&.fetch('count').to_i

    if remaining_null.zero?
      change_column_null table, :platform_id, false
    else
      say "Skipping NOT NULL on #{table}: #{remaining_null} rows still have a NULL platform_id."
    end
  end
end
