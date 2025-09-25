# frozen_string_literal: true

FactoryBot.define do
  factory :noticed_notification, class: 'Noticed::Notification' do
    # Required associations
    association :recipient, factory: :better_together_person
    association :event, factory: :noticed_event

    # Basic attributes - remove type to avoid STI issues
    read_at { nil }
    seen_at { nil }

    # Traits for different states
    trait :read do
      read_at { 1.hour.ago }
    end

    trait :seen do
      seen_at { 30.minutes.ago }
    end

    trait :with_record do
      after(:build) do |notification|
        # Create a record and associate it with the event
        record = create(:better_together_event)
        notification.event.record = record
      end
    end

    trait :recent do
      created_at { 1.hour.ago }
    end

    trait :old do
      created_at { 2.weeks.ago }
    end
  end

  # Factory for Noticed::Event
  factory :noticed_event, class: 'Noticed::Event' do
    type { 'BetterTogether::TestNotifier' }

    # JSON params for the event
    params do
      {
        test_message: 'Test event message',
        action_url: '/test-path'
      }
    end

    # Optional record association
    record { nil }

    trait :with_record do
      association :record, factory: :better_together_event
    end
  end
end
