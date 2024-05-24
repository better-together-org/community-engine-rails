FactoryBot.define do
  factory :geography_state, class: '::BetterTogether::Geography::State', aliases: %i[state] do
    name { Faker::Name.name }
    description { Faker::Lorem.paragraphs(number: 3) }

    iso_code { "#{Faker::String.random(length: 2)}-#{Faker::String.random(length: 2)}" }
  end
end
