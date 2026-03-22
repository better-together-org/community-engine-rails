# frozen_string_literal: true

# Adds sender_key_version to conversations to drive E2E sender key rotation
# on membership changes. Incremented by ConversationParticipant callbacks.
class AddSenderKeyVersionToConversations < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_conversations, :sender_key_version, :integer,
               default: 0, null: false
  end
end
