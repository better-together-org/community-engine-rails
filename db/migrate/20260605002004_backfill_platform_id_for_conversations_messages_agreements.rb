# frozen_string_literal: true

# Phase 2 — Backfill platform_id for conversations, messages, and agreements.
#
# Conversations and agreements are derived from their creator's platform
# membership first, falling back to the host platform only when no membership
# can be found. Messages inherit from their parent conversation. New records
# will pick up Current.platform via the PlatformScoped concern's
# before_validation callback.
class BackfillPlatformIdForConversationsMessagesAgreements < ActiveRecord::Migration[7.2]
  def up
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    backfill_from_creator('better_together_conversations', host_platform_id)

    execute <<~SQL
      UPDATE better_together_messages m
      SET    platform_id = c.platform_id
      FROM   better_together_conversations c
      WHERE  m.conversation_id = c.id
        AND  m.platform_id IS NULL
    SQL

    backfill_from_creator('better_together_agreements', host_platform_id)
  end

  def down
    execute "UPDATE better_together_conversations SET platform_id = NULL"
    execute "UPDATE better_together_messages       SET platform_id = NULL"
    execute "UPDATE better_together_agreements     SET platform_id = NULL"
  end

  private

  def backfill_from_creator(table, host_platform_id)
    execute <<~SQL
      UPDATE #{table} rec
      SET    platform_id = ppm.joinable_id
      FROM   better_together_people p
      JOIN   better_together_person_platform_memberships ppm
        ON   p.id = ppm.member_id
      WHERE  rec.creator_id = p.id
        AND  rec.platform_id IS NULL
        AND  ppm.joinable_id IS NOT NULL
    SQL

    execute <<~SQL
      UPDATE #{table}
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end
end
