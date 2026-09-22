# frozen_string_literal: true

# Phase 2 — Conversation isolation.
# Nullable; backfill assigns host platform to pre-existing records.
class AddPlatformIdToConversations < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_conversations, :platform_id)

    add_reference :better_together_conversations, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
