# frozen_string_literal: true

module BetterTogether
  FactoryBot.define do
    factory :report, class: Report do
      association :reporter, factory: :better_together_person
      association :reportable, factory: :better_together_person
      reason { 'Inappropriate behaviour' }
    end
  end
end
