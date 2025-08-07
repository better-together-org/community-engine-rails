# frozen_string_literal: true

module BetterTogether
  FactoryBot.define do
    factory :person_block, class: PersonBlock do
      association :blocker, factory: :better_together_person
      association :blocked, factory: :better_together_person
    end
  end
end
