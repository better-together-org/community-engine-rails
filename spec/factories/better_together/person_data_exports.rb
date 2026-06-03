# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_person_data_export, class: 'BetterTogether::PersonDataExport' do
    association :person, factory: :better_together_person
    status { 'pending' }
    format { 'json' }
    requested_at { Time.current }

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
    end
  end
end
