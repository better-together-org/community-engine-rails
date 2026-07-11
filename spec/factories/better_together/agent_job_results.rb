# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_agent_job_result, class: 'BetterTogether::AgentJobResult' do
    sequence(:job_id) { |n| "borgberry-job-#{n}" }
    job_type { 'compute' }
    source_system { 'borgberry' }
    status { 'pending' }

    trait :running do
      status { 'running' }
      started_at { 5.seconds.ago }
    end

    trait :completed do
      status { 'completed' }
      started_at { 10.seconds.ago }
      completed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      started_at { 10.seconds.ago }
      completed_at { Time.current }
    end

    trait :with_fleet_node do
      association :fleet_node, factory: :better_together_fleet_node
    end

    trait :with_person_submitter do
      association :submitter, factory: :better_together_person
    end
  end
end
