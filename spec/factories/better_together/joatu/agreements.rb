# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_joatu_agreement, class: 'BetterTogether::Joatu::Agreement', aliases: %i[joatu_agreement] do
    id { SecureRandom.uuid }
    offer { association :better_together_joatu_offer }
    request { association :better_together_joatu_request }
    terms { 'Standard terms' }
    value { '10 tokens' }
  end
end
