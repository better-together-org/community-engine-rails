# frozen_string_literal: true

FactoryBot.define do
  factory :weather_location, class: '::BetterTogether::Weather::Location',
                             aliases: %i[better_together_weather_location] do
    association :settlement, factory: :geography_settlement
    association :source, factory: :weather_source
    external_ref { 'NL/s0000221' }
    observation_station_ref { '8401298' }
    time_zone { 'America/St_Johns' }
    enabled { true }
  end
end
