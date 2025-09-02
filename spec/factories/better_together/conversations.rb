# frozen_string_literal: true

FactoryBot.define do
  factory('better_together/conversation',
          class: 'BetterTogether::Conversation',
          aliases: %i[better_together_conversation conversation]) do
    title { Faker::Lorem.sentence }
    association :creator, factory: :person

    after(:build) do |conversation|
      conversation.participants << conversation.creator unless conversation.participants.include?(conversation.creator)
      # Build an initial message so model-level presence validations pass during factory#create
      if conversation.messages.empty?
        conversation.messages.build(sender: conversation.creator, content: 'Initial factory message')
      end
    end

    after(:create) do |conversation|
      unless conversation.participants.exists?(conversation.creator.id)
        conversation.participants << conversation.creator
      end
    end
  end
end
