# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/geography/continent',
          class: 'BetterTogether::Geography::Continent',
          aliases: %i[continent] do
    name { Faker::Name.name }
    description { Faker::Lorem.paragraphs(number: 3) }
  end
end
