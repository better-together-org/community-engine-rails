# frozen_string_literal: true

FactoryBot.define do
  factory :geography_settlement, class: '::BetterTogether::Geography::Settlement', aliases: %i[settlement] do
    name { Faker::Address.unique.city }
    description { Faker::Lorem.paragraphs(number: 3) }
  end
end
