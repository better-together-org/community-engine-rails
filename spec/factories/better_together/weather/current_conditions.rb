# frozen_string_literal: true

FactoryBot.define do
  factory :weather_current_condition, class: '::BetterTogether::Weather::CurrentCondition',
                                      aliases: %i[better_together_weather_current_condition] do
    association :location, factory: :weather_location
    observed_at { Time.current }
    fetched_at { Time.current }
    payload { { 'values' => { 'temperature_c' => 4.0 } } }
  end
end
