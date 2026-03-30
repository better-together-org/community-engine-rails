# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_person_deletion_request, class: 'BetterTogether::PersonDeletionRequest' do
    association :person, factory: :better_together_person
    status { 'pending' }
    requested_at { Time.current }
    requested_reason { 'Please remove my account data.' }

    trait :cancelled do
      status { 'cancelled' }
      resolved_at { Time.current }
    end
  end
end
