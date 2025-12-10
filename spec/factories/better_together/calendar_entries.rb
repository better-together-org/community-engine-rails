# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_entry, class: 'BetterTogether::CalendarEntry', aliases: [:better_together_calendar_entry] do
    association :calendar, factory: :calendar
    association :event, factory: :event
    starts_at { 1.week.from_now }
    ends_at { 1.week.from_now + 2.hours }
    duration_minutes { 120 }
  end
end
