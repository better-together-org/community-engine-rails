# spec/factories/navigation_areas.rb

FactoryBot.define do
  factory :better_together_navigation_area,
          class: 'BetterTogether::NavigationArea',
          aliases: %i[navigation_area] do
    bt_id { SecureRandom.uuid }
    name { Faker::Commerce.department(max: 1) } # Ensure uniqueness
    style { Faker::Lorem.word }
    visible { Faker::Boolean.boolean }
    slug { name.parameterize }
    navigable_type { ['BetterTogether::Community', 'BetterTogether::Person'].sample }
    navigable_id { SecureRandom.uuid }
    protected { Faker::Boolean.boolean }
  end
end
