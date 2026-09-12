# frozen_string_literal: true

# Phase 6 — Backfill platform_id for join tables from their parent records.
class BackfillPlatformIdForJoinTables < ActiveRecord::Migration[7.2]
  def up
    # AgreementParticipants: inherit from agreements
    if column_exists?(:better_together_agreement_participants, :platform_id)
      execute <<~SQL
        UPDATE better_together_agreement_participants ap
        SET    platform_id = a.platform_id
        FROM   better_together_agreements a
        WHERE  ap.agreement_id = a.id
          AND  ap.platform_id IS NULL
          AND  a.platform_id IS NOT NULL
      SQL
    end

    # ConversationParticipants: inherit from conversations
    if column_exists?(:better_together_conversation_participants, :platform_id)
      execute <<~SQL
        UPDATE better_together_conversation_participants cp
        SET    platform_id = c.platform_id
        FROM   better_together_conversations c
        WHERE  cp.conversation_id = c.id
          AND  cp.platform_id IS NULL
          AND  c.platform_id IS NOT NULL
      SQL
    end

    # EventAttendances: inherit from events
    if column_exists?(:better_together_event_attendances, :platform_id)
      execute <<~SQL
        UPDATE better_together_event_attendances ea
        SET    platform_id = e.platform_id
        FROM   better_together_events e
        WHERE  ea.event_id = e.id
          AND  ea.platform_id IS NULL
          AND  e.platform_id IS NOT NULL
      SQL
    end

    # PersonChecklistItems: inherit from checklists
    return unless column_exists?(:better_together_person_checklist_items, :platform_id)

    execute <<~SQL
      UPDATE better_together_person_checklist_items pci
      SET    platform_id = ch.platform_id
      FROM   better_together_checklists ch
      WHERE  pci.checklist_id = ch.id
        AND  pci.platform_id IS NULL
        AND  ch.platform_id IS NOT NULL
    SQL
  end

  def down
    %w[
      better_together_agreement_participants
      better_together_conversation_participants
      better_together_event_attendances
      better_together_person_checklist_items
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
