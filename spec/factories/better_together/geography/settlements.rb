FactoryBot.define do
  factory :geography_settlement, class: '::BetterTogether::Geography::Settlement', aliases: %i[settlement] do
    name { Faker::Name.name }
    description { Faker::Lorem.paragraphs(number: 3) }
  end
end
