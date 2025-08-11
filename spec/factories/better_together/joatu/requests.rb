# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/joatu/request', class: 'BetterTogether::Joatu::Request',
                                           aliases: %i[better_together_joatu_request joatu_request request] do
    id { SecureRandom.uuid }
    name { Faker::Commerce.material }
    description { Faker::Lorem.paragraph }
    creator { association :better_together_person }

    trait :with_target do
      target { association :better_together_person }
    end
  end
end
