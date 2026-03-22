# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/calendar_entry',
          class: 'BetterTogether::CalendarEntry',
          aliases: [:calendar_entry] do
    association :calendar, factory: 'better_together/calendar'
    association :event, factory: 'better_together/event'

    starts_at { event&.starts_at || 1.week.from_now }
    ends_at { event&.ends_at || (starts_at + 1.hour) }
    duration_minutes { event&.duration_minutes || ((ends_at - starts_at) / 60).to_i }
  end
end
