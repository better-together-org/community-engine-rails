# frozen_string_literal: true

FactoryBot.define do
  factory :weather_observation, class: '::BetterTogether::Weather::Observation',
                                aliases: %i[better_together_weather_observation] do
    association :location, factory: :weather_location
    granularity { 'hourly' }
    sequence(:observed_at) { |n| Time.utc(2026, 11, 1) + n.hours }
    origin { 'live_feed' }
    temperature_c { 3.5 }
  end
end
