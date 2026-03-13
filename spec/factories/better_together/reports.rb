# frozen_string_literal: true

# FactoryBot factories for BetterTogether models.
module BetterTogether
  FactoryBot.define do
    factory :report, class: Report do
      association :reporter, factory: :better_together_person
      association :reportable, factory: :better_together_person
      reason { 'Inappropriate behaviour' }
      category { 'other' }
      harm_level { 'medium' }
      requested_outcome { 'boundary_support' }
      consent_to_contact { true }
      consent_to_restorative_process { false }
      retaliation_risk { false }
    end
  end
end
