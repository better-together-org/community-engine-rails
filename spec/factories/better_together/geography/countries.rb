# frozen_string_literal: true

FactoryBot.define do
  factory :geography_country, class: '::BetterTogether::Geography::Country', aliases: %i[country] do
    name { Faker::Address.unique.country + " #{Faker::Number.unique.number(digits: 5)}" }
    description { Faker::Lorem.paragraphs(number: 3) }

    sequence(:iso_code) { |n| format('%02d', n % 100) }
  end
end
