# frozen_string_literal: true

module BetterTogether
  # Joins people to conversations.
  #
  # E2E note: after_create_commit / after_destroy_commit bump conversation.sender_key_version
  # and broadcast a Turbo Stream replace so the JS form controller's Stimulus value
  # updates, triggering senderKeyVersionValueChanged and resetting #senderKeysReady.
  # This forces createSenderKeyDistribution on the next group message, excluding any
  # removed member from the new key distribution.
  class ConversationParticipant < ApplicationRecord
    belongs_to :conversation
    belongs_to :person

    after_create_commit  :bump_sender_key_version_on_create
    after_destroy_commit :bump_sender_key_version_on_destroy

    private

    def bump_sender_key_version_on_create
      bump_sender_key_version
    end

    def bump_sender_key_version_on_destroy
      bump_sender_key_version
    end

    def bump_sender_key_version
      conversation.increment!(:sender_key_version)
      # broadcast_replace_to (synchronous) avoids ActiveJob serialization of the
      # unsaved Message object; broadcast_replace_later_to would raise
      # ActiveJob::SerializationError because Message.new has no id.
      Turbo::StreamsChannel.broadcast_replace_to(
        conversation,
        target: "e2e_message_form_#{conversation.id}",
        partial: 'better_together/messages/form',
        locals: {
          conversation: conversation.reload,
          message: conversation.messages.build,
          current_user_person_id: nil # no request context in broadcast
        }
      )
    end
  end
end
