# frozen_string_literal: true

require 'faker'

FactoryBot.define do
  factory :event, class: 'BetterTogether::Event' do
    name { "Event \#{Faker::Lorem.unique.word}" }
    starts_at { 1.day.from_now }

    trait :draft do
      after(:create) { |event| event.update_column(:starts_at, nil) }
    end
  end
end
