# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/joatu/offer', class: 'BetterTogether::Joatu::Offer',
                                         aliases: %i[better_together_joatu_offer joatu_offer offer] do
    id { SecureRandom.uuid }
    name { Faker::Commerce.product_name }
    description { Faker::Lorem.paragraph }
    creator { association :better_together_person }
    target_type { nil }
    target_id { nil }
  end
end
