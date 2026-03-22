# frozen_string_literal: true

FactoryBot.define do
  factory :category, class: 'BetterTogether::Category' do
    sequence(:identifier) { |n| "category-#{n}-#{SecureRandom.hex(4)}" }
    sequence(:name) { |n| "#{Faker::Lorem.words(number: 2).join(' ').titleize} #{n} #{SecureRandom.hex(2)}" }
    description { Faker::Lorem.paragraph }
    type { 'BetterTogether::Category' }
    icon { 'fas fa-folder' }

    trait :with_custom_icon do
      icon { 'fas fa-star' }
    end
  end
end
