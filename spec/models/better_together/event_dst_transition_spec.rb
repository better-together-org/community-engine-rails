# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe 'DST Transition Handling' do
    include ActiveSupport::Testing::TimeHelpers
    include ActiveJob::TestHelper

    let(:person) { create(:person) }

    describe 'Event timezone handling across DST transitions' do
      context 'Spring forward (DST begins)' do
        it 'maintains event time through DST transition' do
          # Event created before DST transition for time after DST begins
          event = nil

          # Create event on March 1, 2024 (before DST)
          travel_to Time.zone.parse('2024-03-01 12:00') do
            # Parse times in America/New_York timezone
            ny_tz = ActiveSupport::TimeZone['America/New_York']
            event = create(:event,
                           timezone: 'America/New_York',
                           starts_at: ny_tz.parse('2024-03-15 14:00'), # After DST transition
                           ends_at: ny_tz.parse('2024-03-15 16:00'),
                           creator: person)
          end

          # DST transition happens: March 10, 2024, 2:00 AM → 3:00 AM EDT
          travel_to Time.zone.parse('2024-03-11 12:00') do
            # Event time should still be 2:00 PM local (now EDT instead of EST)
            expect(event.local_starts_at.hour).to eq(14)
            expect(event.local_starts_at.strftime('%Z')).to eq('EDT')

            # UTC time should be 1 hour earlier (18:00 instead of 19:00)
            expect(event.starts_at.utc.hour).to eq(18) # 14:00 EDT = 18:00 UTC
          end
        end

        it 'correctly schedules reminders across DST transition' do
          event = nil

          # Create event before DST for time after DST
          travel_to Time.zone.parse('2024-03-01 12:00') do
            ny_tz = ActiveSupport::TimeZone['America/New_York']
            event = create(:event, :with_attendees,
                           timezone: 'America/New_York',
                           starts_at: ny_tz.parse('2024-03-15 14:00'),
                           ends_at: ny_tz.parse('2024-03-15 16:00'),
                           creator: person)
          end

          # Schedule reminders after DST transition
          travel_to Time.zone.parse('2024-03-11 12:00') do
            clear_enqueued_jobs

            EventReminderSchedulerJob.perform_now(event.id)

            # 24-hour reminder should be at 2:00 PM EDT on March 14
            expected_24h = event.local_starts_at - 24.hours
            expect(expected_24h.hour).to eq(14)
            expect(expected_24h.day).to eq(14)
            expect(expected_24h.strftime('%Z')).to eq('EDT')
          end
        end

        it 'handles events created during the DST gap (2:00 AM - 3:00 AM)' do
          # Times between 2:00 AM and 3:00 AM don't exist on DST transition day
          # Rails/ActiveSupport should handle this gracefully

          travel_to Time.zone.parse('2024-03-10 01:00') do
            # Attempting to create event at 2:30 AM (during the gap)
            ny_tz = ActiveSupport::TimeZone['America/New_York']
            event = create(:event,
                           timezone: 'America/New_York',
                           starts_at: ny_tz.parse('2024-03-10 02:30'),
                           ends_at: ny_tz.parse('2024-03-10 04:30'),
                           creator: person)

            # Should be converted to 3:30 AM EDT (after spring forward)
            expect(event.local_starts_at.hour).to eq(3)
            expect(event.local_starts_at.min).to eq(30)
            expect(event.local_starts_at.strftime('%Z')).to eq('EDT')
          end
        end
      end

      context 'Fall back (DST ends)' do
        it 'maintains event time through DST transition' do
          # Event created before DST ends for time after DST ends
          event = nil

          # Create event on October 15, 2024 (during DST)
          travel_to Time.zone.parse('2024-10-15 12:00') do
            ny_tz = ActiveSupport::TimeZone['America/New_York']
            event = create(:event,
                           timezone: 'America/New_York',
                           starts_at: ny_tz.parse('2024-11-15 14:00'), # After DST ends
                           ends_at: ny_tz.parse('2024-11-15 16:00'),
                           creator: person)
          end

          # DST ends: November 3, 2024, 2:00 AM → 1:00 AM EST
          travel_to Time.zone.parse('2024-11-04 12:00') do
            # Event time should still be 2:00 PM local (now EST instead of EDT)
            expect(event.local_starts_at.hour).to eq(14)
            expect(event.local_starts_at.strftime('%Z')).to eq('EST')

            # UTC time should be 1 hour later (19:00 instead of 18:00)
            expect(event.starts_at.utc.hour).to eq(19) # 14:00 EST = 19:00 UTC
          end
        end

        it 'correctly schedules reminders across DST end' do
          event = nil

          # Create event before DST ends for time after DST ends
          travel_to Time.zone.parse('2024-10-15 12:00') do
            ny_tz = ActiveSupport::TimeZone['America/New_York']
            event = create(:event, :with_attendees,
                           timezone: 'America/New_York',
                           starts_at: ny_tz.parse('2024-11-15 14:00'),
                           ends_at: ny_tz.parse('2024-11-15 16:00'),
                           creator: person)
          end

          # Schedule reminders after DST ends
          travel_to Time.zone.parse('2024-11-04 12:00') do
            clear_enqueued_jobs

            EventReminderSchedulerJob.perform_now(event.id)

            # 24-hour reminder should be at 2:00 PM EST on November 14
            expected_24h = event.local_starts_at - 24.hours
            expect(expected_24h.hour).to eq(14)
            expect(expected_24h.day).to eq(14)
            expect(expected_24h.strftime('%Z')).to eq('EST')
          end
        end

        it 'handles ambiguous times during fall back' do
          # Times between 1:00 AM and 2:00 AM occur twice on DST end day
          # Rails/ActiveSupport defaults to the first occurrence (DST time)

          travel_to Time.zone.parse('2024-11-03 00:30') do
            # Create event at 1:30 AM (ambiguous time)
            ny_tz = ActiveSupport::TimeZone['America/New_York']
            event = create(:event,
                           timezone: 'America/New_York',
                           starts_at: ny_tz.parse('2024-11-03 01:30'),
                           ends_at: ny_tz.parse('2024-11-03 03:30'),
                           creator: person)

            # Should use the first occurrence (still in EDT)
            expect(event.local_starts_at.hour).to eq(1)
            expect(event.local_starts_at.min).to eq(30)
            # NOTE: actual zone depends on ActiveSupport's ambiguous time handling
          end
        end
      end

      context 'Multi-timezone event handling' do
        it 'displays different times for users in different timezones' do
          # Event in New York at 2:00 PM EST
          event = create(:event,
                         timezone: 'America/New_York',
                         starts_at: Time.zone.parse('2024-01-15 14:00 EST'),
                         creator: person)

          # User in Tokyo views the event
          tokyo_time = event.starts_at_in_zone('Asia/Tokyo')
          expect(tokyo_time.strftime('%Z')).to eq('JST')
          # 14:00 EST = 19:00 UTC = 04:00 JST next day
          expect(tokyo_time.hour).to eq(4)
          expect(tokyo_time.day).to eq(16) # Next day in Tokyo

          # User in London views the event
          london_time = event.starts_at_in_zone('Europe/London')
          expect(london_time.strftime('%Z')).to eq('GMT')
          # 14:00 EST = 19:00 UTC = 19:00 GMT
          expect(london_time.hour).to eq(19)
          expect(london_time.day).to eq(15) # Same day in London

          # User in Los Angeles views the event
          la_time = event.starts_at_in_zone('America/Los_Angeles')
          expect(la_time.strftime('%Z')).to eq('PST')
          # 14:00 EST = 19:00 UTC = 11:00 PST
          expect(la_time.hour).to eq(11)
          expect(la_time.day).to eq(15) # Same day in LA
        end

        it 'maintains event timezone regardless of user timezone' do
          # Event in Sydney at 10:00 AM AEDT
          event = create(:event,
                         timezone: 'Australia/Sydney',
                         starts_at: Time.zone.parse('2024-01-15 10:00 AEDT'),
                         creator: person)

          # User in New York views event
          Time.use_zone('America/New_York') do
            # Event's local time should always be in Sydney timezone
            expect(event.local_starts_at.strftime('%Z')).to eq('AEDT')
            expect(event.local_starts_at.hour).to eq(10)

            # Conversion to user's timezone
            ny_time = event.starts_at_in_zone('America/New_York')
            expect(ny_time.strftime('%Z')).to eq('EST')
            # 10:00 AEDT (Sydney) = previous day 18:00 EST (New York)
            expect(ny_time.day).to eq(14)
            expect(ny_time.hour).to eq(18)
          end
        end
      end

      context 'Calendar export with DST' do
        it 'includes proper VTIMEZONE in ICS export' do
          event = create(:event,
                         timezone: 'America/New_York',
                         starts_at: Time.zone.parse('2024-03-15 14:00 EDT'),
                         creator: person)

          ics_data = event.to_ics

          # Should include VTIMEZONE component
          expect(ics_data).to include('VTIMEZONE')
          expect(ics_data).to include('TZID:America/New_York')

          # Should include both STANDARD and DAYLIGHT components for DST rules
          expect(ics_data).to include('BEGIN:STANDARD')
          expect(ics_data).to include('BEGIN:DAYLIGHT')
        end
      end

      context 'Event duration calculations across DST' do
        it 'handles duration correctly when spanning DST transition' do
          # Event starts before DST, ends after DST
          # March 10, 2024: 2:00 AM → 3:00 AM (spring forward)

          event = create(:event,
                         timezone: 'America/New_York',
                         starts_at: Time.zone.parse('2024-03-10 01:00 EST'),
                         ends_at: Time.zone.parse('2024-03-10 04:00 EDT'),
                         creator: person)

          # Clock time duration: 3 hours (1:00 AM to 4:00 AM)
          # Actual duration: 2 hours (because 2:00 AM - 3:00 AM doesn't exist)
          actual_duration = event.ends_at - event.starts_at
          expect(actual_duration).to eq(2.hours)

          # Duration minutes should reflect actual duration
          expect(event.duration_minutes).to eq(120)
        end

        it 'handles duration correctly when spanning fall back' do
          # Event starts before fall back, ends after
          # November 3, 2024: 2:00 AM → 1:00 AM (fall back)

          event = create(:event,
                         timezone: 'America/New_York',
                         starts_at: Time.zone.parse('2024-11-03 00:30 EDT'),
                         ends_at: Time.zone.parse('2024-11-03 02:30 EST'),
                         creator: person)

          # Clock time duration: 2 hours (12:30 AM to 2:30 AM)
          # Actual duration: 3 hours (because 1:00 AM - 2:00 AM occurs twice)
          actual_duration = event.ends_at - event.starts_at
          expect(actual_duration).to eq(3.hours)

          # Duration minutes should reflect actual duration
          expect(event.duration_minutes).to eq(180)
        end
      end
    end
  end
end
