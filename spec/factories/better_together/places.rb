# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_place, class: 'BetterTogether::Place', aliases: %i[place] do
    association :space, factory: :geography_space
    association :community, factory: :better_together_community
  end
end
