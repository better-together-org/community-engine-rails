# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_joatu_category, class: 'BetterTogether::Joatu::Category', aliases: %i[joatu_category] do
    id { SecureRandom.uuid }
    name { Faker::Commerce.department }
  end
end
