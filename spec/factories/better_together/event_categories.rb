# frozen_string_literal: true

FactoryBot.define do
  factory :event_category, class: 'BetterTogether::EventCategory' do
    sequence(:identifier) { |n| "event-category-#{n}-#{SecureRandom.hex(4)}" }
    sequence(:name) { |n| "#{Faker::Lorem.words(number: 2).join(' ').titleize} #{n} #{SecureRandom.hex(2)}" }
    description { Faker::Lorem.paragraph }
    type { 'BetterTogether::EventCategory' }
  end
end
