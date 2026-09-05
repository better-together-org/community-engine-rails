# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_safety_case,
          class: 'BetterTogether::Safety::Case',
          aliases: %i[safety_case] do
    association :report, factory: :report
    status { 'submitted' }
    lane { 'restorative' }
    category { 'harassment' }
    harm_level { 'medium' }
    requested_outcome { 'boundary_support' }
  end
end
