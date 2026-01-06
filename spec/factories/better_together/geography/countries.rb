# frozen_string_literal: true

FactoryBot.define do
  factory :geography_country, class: '::BetterTogether::Geography::Country', aliases: %i[country] do
    name { Faker::Address.unique.country }
    description { Faker::Lorem.paragraphs(number: 3) }

    iso_code { Faker::String.random(length: 2).to_s }
  end
end
