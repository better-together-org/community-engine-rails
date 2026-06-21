# frozen_string_literal: true

# Phase 5 — Checklist and CallForInterest isolation.
# Nullable; backfill assigns host platform to pre-existing records.
class AddPlatformIdToChecklistsAndCalls < ActiveRecord::Migration[7.2]
  def change
    add_reference :better_together_checklists, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true

    add_reference :better_together_calls_for_interest, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
