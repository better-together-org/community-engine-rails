# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/conversation',
          class: 'BetterTogether::Conversation',
          aliases: %i[better_together_conversation conversation]) do
    title { Faker::Lorem.sentence }
    association :creator, factory: :person
  end
end
