# frozen_string_literal: true

# Phase 8 — Safety case chain: Case, Action, Agreement, Note.
class AddPlatformIdToSafetyTables < ActiveRecord::Migration[7.2]
  def change
    %w[
      better_together_safety_cases
      better_together_safety_actions
      better_together_safety_agreements
      better_together_safety_notes
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end
  end
end
