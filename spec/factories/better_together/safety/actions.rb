# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_safety_action,
          class: 'BetterTogether::Safety::Action',
          aliases: %i[safety_action] do
    association :safety_case, factory: :safety_case
    association :actor, factory: :better_together_person
    action_type { 'watch_flag' }
    status { 'active' }
    reason { 'Monitoring account for repeat violations' }
    review_at { 7.days.from_now }
  end
end
