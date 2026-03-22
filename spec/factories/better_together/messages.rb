# frozen_string_literal: true

FactoryBot.define do
  factory('better-together/message',
          class: 'BetterTogether::Message',
          aliases: %i[better_together_message message]) do
    content { Faker::Lorem.paragraph }
    association :sender, factory: :person
    association :conversation

    after(:create) do |message|
      BetterTogether::NewMessageNotifier.with(record: message,
                                              conversation_id: message.conversation_id)
                                        .deliver(message.conversation.participants)
    end
  end
end
