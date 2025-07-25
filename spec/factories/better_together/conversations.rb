# frozen_string_literal: true

FactoryBot.define do
  factory(:better_together_conversation, class: 'BetterTogether::Conversation', aliases: %i[conversation]) do
    title { Faker::Lorem.sentence }
    association :creator, factory: :person
  end
end
