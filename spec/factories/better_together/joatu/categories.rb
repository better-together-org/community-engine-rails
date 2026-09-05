# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_joatu_category, class: 'BetterTogether::Joatu::Category', aliases: %i[joatu_category] do
    id { SecureRandom.uuid }
    sequence(:name) { |n| "#{Faker::Commerce.department} #{n} #{SecureRandom.hex(2)}" }
  end
end
