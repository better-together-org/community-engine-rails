# frozen_string_literal: true

FactoryBot.define do
  factory :geography_map, class: 'BetterTogether::Geography::Map',
                          aliases: %i[map better_together_geography_map] do
    transient do
      sequence(:map_number) { |n| n }
    end

    title { "Map #{map_number}" }
    description { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
    sequence(:identifier) { |n| "map-#{n}" }
    zoom { 10 }
    privacy { 'public' }
    protected { false }

    association :creator, factory: :better_together_person

    after(:build) do |map|
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      map.center ||= factory.point(-57.9474, 48.9517) # Corner Brook, NL
    end

    trait :protected do
      protected { true }
    end

    trait :private do
      privacy { 'private' }
    end

    trait :with_mappable do
      association :mappable, factory: :better_together_community
    end
  end
end
