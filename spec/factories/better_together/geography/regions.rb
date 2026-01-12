# frozen_string_literal: true

FactoryBot.define do
  factory :geography_region, class: '::BetterTogether::Geography::Region', aliases: %i[region] do
    sequence(:name) { |n| "Region #{n}" }
    description { Faker::Lorem.paragraphs(number: 3) }
  end
end
