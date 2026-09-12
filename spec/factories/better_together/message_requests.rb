# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/message_request',
          class: 'BetterTogether::MessageRequest',
          aliases: %i[better_together_message_request message_request] do
    association :sender,    factory: :better_together_person
    association :recipient, factory: :better_together_person
    association :platform,  factory: :better_together_platform
    note { 'Hi, I would like to connect with you to discuss our shared community projects.' }
    status { 'pending' }
  end
end
