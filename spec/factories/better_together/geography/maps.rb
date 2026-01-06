# frozen_string_literal: true

FactoryBot.define do
  factory :geography_map, class: 'Geography::Map' do
    sequence(:name) { |n| "Test Map #{n}" }
  end
end
