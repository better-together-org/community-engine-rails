# frozen_string_literal: true

FactoryBot.define do
  factory :event_category, class: 'BetterTogether::EventCategory' do
    sequence(:identifier) { |n| "event_category_#{n}" }
    name { Faker::Lorem.unique.words(number: 2).join(' ').titleize }
    description { Faker::Lorem.paragraph }
    type { 'BetterTogether::EventCategory' }
  end
end
