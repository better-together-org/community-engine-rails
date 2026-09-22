# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_person_purge_audit, class: 'BetterTogether::PersonPurgeAudit' do
    association :person, factory: :better_together_person
    association :person_deletion_request, factory: :better_together_person_deletion_request
    status { 'running' }
    person_identifier_snapshot { 'test-identifier' }
    person_name_snapshot { 'Test Person' }
    requested_at { Time.current }
    reviewed_at { Time.current }
    started_at { Time.current }
    inventory_snapshot { { 'entries' => [] } }
    execution_snapshot { { 'destroyed_entries' => [] } }

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      failed_at { Time.current }
      error_message { 'Simulated error' }
    end
  end
end
