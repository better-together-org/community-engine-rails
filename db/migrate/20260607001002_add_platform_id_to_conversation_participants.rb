# frozen_string_literal: true

# Phase 6 — Platform isolation for join tables.
# ConversationParticipant allows cross-platform queries without this column.
class AddPlatformIdToConversationParticipants < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_conversation_participants, :platform_id)

    add_reference :better_together_conversation_participants, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
