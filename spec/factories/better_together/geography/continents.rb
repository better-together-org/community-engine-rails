# frozen_string_literal: true

FactoryBot.define do
  factory :geography_continent, class: '::BetterTogether::Geography::Continent',
                                aliases: %i[continent better_together_geography_continent] do
    transient do
      sequence(:continent_number) { |n| n }
    end

    name { "Continent #{continent_number}" }
    description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    sequence(:identifier) { |n| "continent-#{n}" }
    protected { false }

    association :community, factory: :better_together_community

    trait :protected do
      protected { true }
    end

    trait :with_countries do
      after(:create) do |continent|
        create_list(:geography_country, 2, continents: [continent])
      end
    end
  end
end
