# frozen_string_literal: true

FactoryBot.define do
  factory :geography_region, class: '::BetterTogether::Geography::Region',
                             aliases: %i[region better_together_geography_region] do
    transient do
      sequence(:region_number) { |n| n }
    end

    name { "Region #{region_number}" }
    description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    sequence(:identifier) { |n| "region-#{n}" }
    protected { false }

    association :community, factory: :better_together_community
    association :country, factory: :geography_country
    association :state, factory: :geography_state

    trait :protected do
      protected { true }
    end

    trait :without_country do
      country { nil }
    end

    trait :without_state do
      state { nil }
    end

    trait :with_settlements do
      after(:create) do |region|
        create_list(:geography_settlement, 2, regions: [region])
      end
    end
  end
end
