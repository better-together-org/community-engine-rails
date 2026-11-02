# frozen_string_literal: true

FactoryBot.define do
  factory :weather_source, class: '::BetterTogether::Weather::Source',
                           aliases: %i[better_together_weather_source] do
    sequence(:identifier) { |n| "weather-source-#{n}" }
    adapter_key { 'environment_canada' }
    config { {} }
    enabled { true }
  end
end
