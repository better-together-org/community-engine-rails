# frozen_string_literal: true

# spec/factories/navigation_items.rb

FactoryBot.define do
  factory :better_together_navigation_item,
          class: 'BetterTogether::NavigationItem',
          aliases: %i[navigation_item] do
    id { SecureRandom.uuid }
    association :navigation_area, factory: :better_together_navigation_area
    title { Faker::Lorem.unique.sentence }
    url { Faker::Internet.url }
    icon { Faker::Lorem.word }
    position { Faker::Number.between(from: 0, to: 10) }
    visible { Faker::Boolean.boolean }
    item_type { %w[link dropdown separator].sample }
    protected { Faker::Boolean.boolean }
    linkable_type { [nil, 'BetterTogether::Page'].sample }
    linkable_id { linkable_type ? SecureRandom.uuid : nil }
    parent_id { nil } # Assign in tests if needed
  end
end
