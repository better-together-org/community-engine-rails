# frozen_string_literal: true

# Phase 5 — Wizard isolation.
# Each platform can have its own onboarding wizard(s).
# Nullable; backfill assigns host platform to pre-existing records.
class AddPlatformIdToWizards < ActiveRecord::Migration[7.2]
  def change
    add_reference :better_together_wizards, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
