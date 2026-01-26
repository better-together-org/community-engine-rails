# frozen_string_literal: true

FactoryBot.define do
  factory :geography_state, class: '::BetterTogether::Geography::State',
                            aliases: %i[state better_together_geography_state] do
    transient do
      sequence(:state_number) { |n| n }
    end

    name { "State #{state_number}" }
    description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    sequence(:identifier) { |n| "state-#{n}-#{SecureRandom.hex(3)}" }
    iso_code { "#{SecureRandom.alphanumeric(2).upcase}-#{SecureRandom.alphanumeric(2).upcase}" }
    protected { false }

    association :community, factory: :better_together_community
    association :country, factory: :geography_country

    trait :protected do
      protected { true }
    end

    trait :with_regions do
      after(:create) do |state|
        create_list(:geography_region, 2, state:)
      end
    end

    trait :with_settlements do
      after(:create) do |state|
        create_list(:geography_settlement, 3, state:)
      end
    end
  end
end
