FactoryBot.define do
  factory :geography_region, class: '::BetterTogether::Geography::Region', aliases: %i[region] do
    name { Faker::Name.name }
    description { Faker::Lorem.paragraphs(number: 3) }
  end
end
