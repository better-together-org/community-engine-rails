# frozen_string_literal: true

# Phase 8 — Backfill safety tables: Case from report, then Action/Agreement/Note from case.
class BackfillPlatformIdForSafetyTables < ActiveRecord::Migration[7.2]
  def up
    # Step 1: Safety::Case from report
    if column_exists?(:better_together_safety_cases, :platform_id)
      execute <<~SQL
        UPDATE better_together_safety_cases sc
        SET    platform_id = r.platform_id
        FROM   better_together_reports r
        WHERE  sc.report_id = r.id
          AND  sc.platform_id IS NULL
          AND  r.platform_id IS NOT NULL
      SQL
    end

    # Step 2: Safety::Action, Safety::Agreement, Safety::Note from case
    [
      %i[better_together_safety_actions safety_case_id],
      %i[better_together_safety_agreements safety_case_id],
      %i[better_together_safety_notes safety_case_id]
    ].each do |table, fk|
      next unless column_exists?(table, :platform_id)

      execute <<~SQL
        UPDATE #{table} t
        SET    platform_id = sc.platform_id
        FROM   better_together_safety_cases sc
        WHERE  t.#{fk} = sc.id
          AND  t.platform_id IS NULL
          AND  sc.platform_id IS NOT NULL
      SQL
    end
  end

  def down
    %w[
      better_together_safety_cases
      better_together_safety_actions
      better_together_safety_agreements
      better_together_safety_notes
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
