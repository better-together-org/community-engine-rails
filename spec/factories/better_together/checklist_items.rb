# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_checklist_item, class: 'BetterTogether::ChecklistItem' do
    id { SecureRandom.uuid }
    association :checklist, factory: :better_together_checklist
    label { Faker::Lorem.sentence(word_count: 3) }
    position { 0 }
    protected { false }
    privacy { 'private' }
  end
end
