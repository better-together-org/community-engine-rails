# frozen_string_literal: true

FactoryBot.define do
  factory :geography_country_continent, class: 'BetterTogether::Geography::CountryContinent',
                                        aliases: %i[better_together_geography_country_continent] do
    association :country, factory: :geography_country
    association :continent, factory: :geography_continent
  end
end
