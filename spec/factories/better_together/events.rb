# frozen_string_literal: true

require 'faker'

FactoryBot.define do
  factory 'better_together/event',
          class: 'BetterTogether::Event',
          aliases: %i[better_together_event event] do
    # Remove manual ID setting - let Rails handle this
    identifier { Faker::Internet.unique.uuid }
    name { Faker::Lorem.unique.words(number: 3).join(' ').titleize }
    description { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
    starts_at { 1.week.from_now }
    ends_at { 1.week.from_now + 2.hours }
    registration_url { Faker::Internet.url }
    privacy { 'public' }

    association :creator, factory: :person

    trait :with_simple_location do
      after(:build) do |event|
        event.location = build(:locatable_location, :simple, locatable: event)
      end
    end

    trait :with_address_location do
      after(:build) do |event|
        event.location = build(:locatable_location, :with_address, locatable: event)
      end
    end

    trait :with_building_location do
      after(:build) do |event|
        event.location = build(:locatable_location, :with_building, locatable: event)
      end
    end

    trait :draft do
      starts_at { nil }
      ends_at { nil }
    end

    trait :past do
      starts_at { 1.week.ago }
      ends_at { 1.week.ago + 2.hours }
    end

    trait :upcoming do
      starts_at { 1.week.from_now }
      ends_at { 1.week.from_now + 2.hours }
    end

    trait :with_attendees do
      after(:create) do |event|
        create_list(:event_attendance, 3, event: event)
      end
    end
  end
end
