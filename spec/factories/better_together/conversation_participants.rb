# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/conversation_participant',
          class: 'BetterTogether::ConversationParticipant',
          aliases: %i[better_together_conversation_participant conversation_participant]) do
    association :conversation
    association :person
  end
end
