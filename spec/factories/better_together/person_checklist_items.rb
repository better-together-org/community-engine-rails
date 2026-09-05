# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_person_checklist_item,
          class: 'BetterTogether::PersonChecklistItem',
          aliases: %i[person_checklist_item] do
    association :person, factory: :better_together_person
    association :checklist, factory: :better_together_checklist
    association :checklist_item, factory: :better_together_checklist_item

    trait :completed do
      completed_at { Time.current }
    end
  end
end
