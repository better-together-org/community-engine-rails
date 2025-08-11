# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/joatu/request', class: 'BetterTogether::Joatu::Request',
                                           aliases: %i[better_together_joatu_request joatu_request request] do
    id { SecureRandom.uuid }
    name { Faker::Commerce.material }
    description { Faker::Lorem.paragraph }
    creator { association :better_together_person }

    after(:build) do |request|
      request.categories << build(:better_together_joatu_category) if request.categories.blank?
    end
  end
end
