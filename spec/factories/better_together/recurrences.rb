# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/recurrence',
          class: 'BetterTogether::Recurrence',
          aliases: [:recurrence] do
    association :schedulable, factory: 'better_together/event'

    rule do
      s = IceCube::Schedule.new(schedulable&.starts_at || 1.week.from_now)
      s.add_recurrence_rule(IceCube::Rule.weekly(1))
      s.to_yaml
    end

    trait :daily do
      rule do
        s = IceCube::Schedule.new(schedulable&.starts_at || 1.week.from_now)
        s.add_recurrence_rule(IceCube::Rule.daily(1))
        s.to_yaml
      end
    end

    trait :weekly do
      rule do
        s = IceCube::Schedule.new(schedulable&.starts_at || 1.week.from_now)
        s.add_recurrence_rule(IceCube::Rule.weekly(1))
        s.to_yaml
      end
    end

    trait :monthly do
      rule do
        s = IceCube::Schedule.new(schedulable&.starts_at || 1.week.from_now)
        s.add_recurrence_rule(IceCube::Rule.monthly(1))
        s.to_yaml
      end
    end

    trait :yearly do
      rule do
        s = IceCube::Schedule.new(schedulable&.starts_at || 1.week.from_now)
        s.add_recurrence_rule(IceCube::Rule.yearly(1))
        s.to_yaml
      end
    end

    trait :with_end_date do
      ends_on { 6.months.from_now.to_date }
    end

    trait :with_exceptions do
      exception_dates { [1.week.from_now.to_date, 2.weeks.from_now.to_date] }
    end
  end
end
