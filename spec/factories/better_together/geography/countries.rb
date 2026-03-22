# frozen_string_literal: true

FactoryBot.define do
  factory :geography_country, class: '::BetterTogether::Geography::Country',
                              aliases: %i[country better_together_geography_country] do
    transient do
      sequence(:country_number) { |n| n }
    end

    name { "Country #{country_number}" }
    description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    sequence(:identifier) { |n| "country-#{n}-#{SecureRandom.hex(3)}" }
    sequence(:iso_code) do |n|
      letters = ('A'..'Z').to_a
      worker_raw = ENV.fetch('TEST_ENV_NUMBER', '')
      worker_index = worker_raw.to_s.empty? ? 0 : worker_raw.to_i
      first = letters[worker_index % letters.length]
      second = letters[n % letters.length]
      "#{first}#{second}"
    end
    protected { false }

    association :community, factory: :better_together_community

    trait :protected do
      protected { true }
    end

    trait :with_continents do
      after(:create) do |country|
        create_list(:geography_continent, 2, countries: [country])
      end
    end

    trait :with_states do
      after(:create) do |country|
        create_list(:geography_state, 3, country:)
      end
    end
  end
end
