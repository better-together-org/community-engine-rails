# frozen_string_literal: true

# Phase 2 — Backfill platform_id for conversations, messages, and agreements.
#
# Conversations and agreements are assigned to the host platform (the only
# platform that existed before this migration series). Messages inherit from
# their parent conversation. This is a conservative safe default — all existing
# data is single-platform. New records will pick up Current.platform via the
# PlatformScoped concern's before_validation callback.
class BackfillPlatformIdForConversationsMessagesAgreements < ActiveRecord::Migration[7.2]
  def up
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    execute <<~SQL
      UPDATE better_together_conversations
      SET    platform_id = '#{host_platform_id}'
      WHERE  platform_id IS NULL
    SQL

    execute <<~SQL
      UPDATE better_together_messages m
      SET    platform_id = c.platform_id
      FROM   better_together_conversations c
      WHERE  m.conversation_id = c.id
        AND  m.platform_id IS NULL
    SQL

    execute <<~SQL
      UPDATE better_together_agreements
      SET    platform_id = '#{host_platform_id}'
      WHERE  platform_id IS NULL
    SQL
  end

  def down
    execute "UPDATE better_together_conversations SET platform_id = NULL"
    execute "UPDATE better_together_messages       SET platform_id = NULL"
    execute "UPDATE better_together_agreements     SET platform_id = NULL"
  end
end
