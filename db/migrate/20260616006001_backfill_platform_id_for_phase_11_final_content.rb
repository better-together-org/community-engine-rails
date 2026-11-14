# frozen_string_literal: true

# Phase 11 — Backfill final content isolation tables
class BackfillPlatformIdForPhase11FinalContent < ActiveRecord::Migration[7.2]
  def up # rubocop:todo Metrics/CyclomaticComplexity
    # Uploads, Checklists, Wizards, CallsForInterest — all from creator
    %w[
      better_together_uploads
      better_together_checklists
      better_together_wizards
      better_together_calls_for_interest
    ].each do |table|
      next unless column_exists?(table, :platform_id)
      next unless column_exists?(table, :creator_id)

      execute <<~SQL
        UPDATE #{table} t
        SET    platform_id = ppm.joinable_id
        FROM   better_together_people p
        JOIN   better_together_person_platform_memberships ppm
          ON   p.id = ppm.member_id
        WHERE  t.creator_id = p.id
          AND  t.platform_id IS NULL
          AND  ppm.joinable_id IS NOT NULL
      SQL
    end

    # Host platform fallback for any remaining nulls
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    %w[
      better_together_uploads
      better_together_checklists
      better_together_wizards
      better_together_calls_for_interest
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
      better_together_uploads
      better_together_checklists
      better_together_wizards
      better_together_calls_for_interest
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
