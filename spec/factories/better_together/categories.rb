# frozen_string_literal: true

FactoryBot.define do
  factory :category, class: 'BetterTogether::Category' do
    sequence(:identifier) { |n| "category_#{n}" }
    name { Faker::Lorem.unique.words(number: 2).join(' ').titleize }
    description { Faker::Lorem.paragraph }
    type { 'BetterTogether::Category' }
    icon { 'fas fa-folder' }

    trait :with_custom_icon do
      icon { 'fas fa-star' }
    end
  end
end
