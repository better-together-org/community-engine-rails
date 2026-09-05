# frozen_string_literal: true

# Phase 8 — Backfill simple child tables from their parent platform_id.
class BackfillPlatformIdForChildTables < ActiveRecord::Migration[7.2]
  PARENT_MAP = [
    %i[better_together_agreement_terms better_together_agreements agreement_id],
    %i[better_together_wizard_steps better_together_wizards wizard_id],
    %i[better_together_wizard_step_definitions better_together_wizards wizard_id],
    %i[better_together_checklist_items better_together_checklists checklist_id],
    %i[better_together_joatu_settlements better_together_joatu_agreements agreement_id],
    %i[better_together_event_hosts better_together_events event_id],
    %i[better_together_calendar_entries better_together_events event_id],
    %i[better_together_person_community_memberships better_together_communities joinable_id]
  ].freeze

  def up
    PARENT_MAP.each do |child_table, parent_table, fk|
      next unless column_exists?(child_table, :platform_id)

      execute <<~SQL
        UPDATE #{child_table} c
        SET    platform_id = p.platform_id
        FROM   #{parent_table} p
        WHERE  c.#{fk} = p.id
          AND  c.platform_id IS NULL
          AND  p.platform_id IS NOT NULL
      SQL
    end
  end

  def down
    PARENT_MAP.each do |child_table, _, _|
      next unless column_exists?(child_table, :platform_id)

      execute "UPDATE #{child_table} SET platform_id = NULL"
    end

    return unless column_exists?(:better_together_comments, :platform_id)

    execute "UPDATE better_together_comments SET platform_id = NULL"
  end
end
