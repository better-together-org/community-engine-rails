# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_joatu_request, class: 'BetterTogether::Joatu::Request', aliases: %i[joatu_request] do
    id { SecureRandom.uuid }
    name { Faker::Commerce.material }
    description { Faker::Lorem.paragraph }
    creator { association :better_together_person }
  end
end
