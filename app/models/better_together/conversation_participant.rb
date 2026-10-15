# frozen_string_literal: true

module BetterTogether
  # Joins people to conversations.
  class ConversationParticipant < PlatformRecord
    belongs_to :conversation
    belongs_to :person
  end
end
