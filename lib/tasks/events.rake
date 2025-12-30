# frozen_string_literal: true

namespace :better_together do
  namespace :events do
    desc 'Calculate and set ends_at for events that have starts_at and duration_minutes but no ends_at'
    task recalculate_end_times: :environment do
      events_updated = 0

      BetterTogether::Event.where.not(starts_at: nil)
                           .where.not(duration_minutes: nil)
                           .where(ends_at: nil)
                           .find_each do |event|
                             event.update_column(:ends_at, event.starts_at + event.duration_minutes.minutes)
                             events_updated += 1
                             print '.' if (events_updated % 10).zero?
      end

      puts "\n✅ Updated #{events_updated} events with calculated end times"
    end
  end
end
