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

    # Explicit privacy: 'public' -- the community factory defaults to 'private',
    # which would cap this record's own privacy (default 'public') below the
    # PrivacyCeilingValidatable ceiling. Real create_primary_community mirrors
    # the parent's privacy automatically; the factory bypasses that path by
    # supplying its own community, so it must match by hand.
    association :community, factory: :better_together_community, privacy: 'public'

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
