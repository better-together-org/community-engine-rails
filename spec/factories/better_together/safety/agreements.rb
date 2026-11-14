# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_safety_agreement,
          class: 'BetterTogether::Safety::Agreement',
          aliases: %i[safety_agreement] do
    association :safety_case, factory: :safety_case
    association :created_by, factory: :better_together_person
    status { 'proposed' }
    summary { 'Both parties agree to no further direct contact.' }
    commitments { 'Refrain from posting about the other party.' }
  end
end
