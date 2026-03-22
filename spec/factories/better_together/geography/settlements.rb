# frozen_string_literal: true

FactoryBot.define do
  factory :geography_settlement, class: '::BetterTogether::Geography::Settlement',
                                 aliases: %i[settlement better_together_geography_settlement] do
    transient do
      sequence(:settlement_number) { |n| n }
    end

    name { "Settlement #{settlement_number}" }
    description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    sequence(:identifier) { |n| "settlement-#{n}" }
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

    trait :with_regions do
      after(:create) do |settlement|
        create_list(:geography_region, 2, settlements: [settlement])
      end
    end
  end
end
