# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_safety_note,
          class: 'BetterTogether::Safety::Note',
          aliases: %i[safety_note] do
    association :safety_case, factory: :safety_case
    association :author, factory: :better_together_person
    body { 'Initial triage complete. Assigned to restorative track.' }
    visibility { 'internal_only' }
  end
end
