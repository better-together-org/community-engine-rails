# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_checklist, class: 'BetterTogether::Checklist' do
    id { SecureRandom.uuid }
    creator { nil }
    protected { false }
    privacy { 'private' }
    sequence(:title) { |n| "Test Checklist #{n}" }
  end
end
