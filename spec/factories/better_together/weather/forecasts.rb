# frozen_string_literal: true

FactoryBot.define do
  factory :weather_forecast, class: '::BetterTogether::Weather::Forecast',
                             aliases: %i[better_together_weather_forecast] do
    association :location, factory: :weather_location
    kind { 'hourly' }
    sequence(:issued_at) { |n| Time.utc(2026, 11, 1) + n.hours }
    fetched_at { issued_at }
    payload { { 'periods' => [] } }
  end
end
