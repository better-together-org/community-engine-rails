# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module BetterTogether
  RSpec.describe RecurringSchedulable do
    include ActiveSupport::Testing::TimeHelpers

    let(:event_class) do
      Class.new(Event) do
        # Temporary test class
      end
    end

    let(:event) do
      create(:event,
             name: 'Weekly Team Meeting',
             starts_at: Time.zone.parse('2026-01-15 14:00'),
             duration_minutes: 60)
    end

    let(:weekly_schedule) do
      s = IceCube::Schedule.new(event.starts_at)
      s.add_recurrence_rule(IceCube::Rule.weekly(1))
      s
    end

    describe '#recurring?' do
      it 'returns false when no recurrence exists' do
        expect(event).not_to be_recurring
      end

      it 'returns true when recurrence exists' do
        event.create_recurrence!(rule: weekly_schedule.to_yaml)
        expect(event).to be_recurring
      end
    end

    describe '#schedule' do
      it 'returns nil when no recurrence' do
        expect(event.schedule).to be_nil
      end

      it 'returns IceCube::Schedule when recurrence exists' do
        event.create_recurrence!(rule: weekly_schedule.to_yaml)
        expect(event.schedule).to be_a(IceCube::Schedule)
      end
    end

    describe '#occurrences_between' do
      let(:start_date) { Time.zone.parse('2026-01-15') }
      let(:end_date) { Time.zone.parse('2026-02-15') }

      context 'without recurrence' do
        it 'returns array with self' do
          occurrences = event.occurrences_between(start_date, end_date)
          expect(occurrences).to eq([event])
        end
      end

      context 'with recurrence' do
        before do
          event.create_recurrence!(rule: weekly_schedule.to_yaml)
        end

        it 'returns Occurrence objects' do
          occurrences = event.occurrences_between(start_date, end_date)
          expect(occurrences).to all(be_a(Occurrence))
        end

        it 'returns multiple occurrences for weekly recurrence' do
          occurrences = event.occurrences_between(start_date, end_date)
          expect(occurrences.length).to be >= 4 # At least 4 weeks
        end

        it 'each occurrence has correct starts_at' do
          occurrences = event.occurrences_between(start_date, end_date)
          first_occurrence = occurrences.first
          expect(first_occurrence.starts_at.hour).to eq(14) # Same hour as parent
        end
      end
    end

    describe '#next_occurrence' do
      context 'without recurrence' do
        it 'returns nil' do
          expect(event.next_occurrence).to be_nil
        end
      end

      context 'with recurrence' do
        before do
          event.create_recurrence!(rule: weekly_schedule.to_yaml)
        end

        it 'returns Occurrence object' do
          travel_to Time.zone.parse('2026-01-16 12:00') do
            next_occ = event.next_occurrence
            expect(next_occ).to be_a(Occurrence)
          end
        end

        it 'returns next occurrence after given time' do
          travel_to Time.zone.parse('2026-01-16 12:00') do
            next_occ = event.next_occurrence
            expect(next_occ.starts_at).to be > Time.current
            expect(next_occ.starts_at.to_date).to eq(Date.parse('2026-01-22'))
          end
        end

        it 'accepts custom after parameter' do
          after_time = Time.zone.parse('2026-01-30 12:00')
          next_occ = event.next_occurrence(after: after_time)
          expect(next_occ.starts_at).to be > after_time
        end
      end
    end

    describe 'nested attributes' do
      it 'accepts nested recurrence attributes' do
        event_params = {
          name: 'New Event',
          recurrence_attributes: {
            rule: weekly_schedule.to_yaml,
            ends_on: Date.parse('2026-12-31')
          }
        }

        new_event = Event.create!(event_params.merge(
                                    starts_at: 1.week.from_now,
                                    identifier: SecureRandom.uuid
                                  ))

        expect(new_event.recurrence).to be_present
        expect(new_event.recurrence.ends_on).to eq(Date.parse('2026-12-31'))
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
