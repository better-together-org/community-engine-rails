# frozen_string_literal: true

# Phase 11 — Final content isolation: remaining user-generated and workflow tables
class AddPlatformIdToPhase11FinalContent < ActiveRecord::Migration[7.2]
  def change
    # User-generated content & workflows (4 tables)
    # Note: agreements, categories, categorizations, wizard_steps, wizard_step_definitions,
    # checklist_items were already scoped in earlier phases
    %w[
      better_together_uploads
      better_together_checklists
      better_together_wizards
      better_together_calls_for_interest
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end
  end
end
