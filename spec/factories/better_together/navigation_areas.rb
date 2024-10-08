# frozen_string_literal: true

# spec/factories/navigation_areas.rb

FactoryBot.define do
  factory :better_together_navigation_area,
          class: 'BetterTogether::NavigationArea',
          aliases: %i[navigation_area] do
    id { SecureRandom.uuid }
    name { Faker::Lorem.unique.sentence } # Ensure uniqueness
    identifier { name.parameterize }
    style { Faker::Lorem.word }
    visible { Faker::Boolean.boolean }
    slug { name.parameterize }
    navigable_type { ['BetterTogether::Community', 'BetterTogether::Person'].sample }
    navigable_id { SecureRandom.uuid }
    protected { Faker::Boolean.boolean }
  end
end
