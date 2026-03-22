# frozen_string_literal: true

FactoryBot.define do
  factory :categorization, class: 'BetterTogether::Categorization' do
    association :category, factory: :event_category
    association :categorizable, factory: :event
  end
end
