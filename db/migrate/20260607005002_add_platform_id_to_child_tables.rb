# frozen_string_literal: true

# Phase 8 — Simple child tables: AgreementTerm, WizardStep/Definition,
# ChecklistItem, Joatu::Settlement, EventHost, CalendarEntry,
# PersonCommunityMembership, Comment.
class AddPlatformIdToChildTables < ActiveRecord::Migration[7.2]
  def change
    %w[
      better_together_agreement_terms
      better_together_wizard_steps
      better_together_wizard_step_definitions
      better_together_checklist_items
      better_together_joatu_settlements
      better_together_event_hosts
      better_together_calendar_entries
      better_together_person_community_memberships
      better_together_comments
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end
  end
end
