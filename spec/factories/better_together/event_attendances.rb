# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/event_attendance',
          class: 'BetterTogether::EventAttendance',
          aliases: %i[event_attendance] do
    status { 'going' }

    association :event, factory: :event
    association :person, factory: :person

    trait :interested do
      status { 'interested' }
    end

    trait :going do
      status { 'going' }
    end
  end
end
