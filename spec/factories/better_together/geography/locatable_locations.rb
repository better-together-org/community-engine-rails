# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/geography/locatable_location',
          class: 'BetterTogether::Geography::LocatableLocation',
          aliases: %i[locatable_location] do
    name { Faker::Address.street_address }

    association :locatable, factory: :event, strategy: :build

    trait :simple do
      name { Faker::Company.name }
      location { nil }
    end

    trait :with_address do
      name { nil }
      association :location, factory: :better_together_address
      location_type { 'BetterTogether::Address' }
    end

    trait :with_building do
      name { nil }
      association :location, factory: :better_together_infrastructure_building
      location_type { 'BetterTogether::Infrastructure::Building' }
    end
  end
end
