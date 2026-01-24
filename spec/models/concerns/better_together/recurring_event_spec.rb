# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe RecurringEvent do
    let(:event) { create(:event, :upcoming) }

    describe 'validations' do
      context 'when is_recurring is true' do
        it 'requires recurrence_rule' do
          event.is_recurring = true
          event.recurrence_rule = nil

          expect(event).not_to be_valid
          expect(event.errors[:recurrence_rule]).to include('can\'t be blank')
        end

        it 'validates recurrence_rule is valid ice_cube YAML' do
          event.is_recurring = true
          event.recurrence_rule = 'invalid yaml content'

          expect(event).not_to be_valid
          expect(event.errors[:recurrence_rule]).to be_present
        end
      end

      context 'when is_recurring is false' do
        it 'does not require recurrence_rule' do
          event.is_recurring = false
          event.recurrence_rule = nil

          expect(event).to be_valid
        end
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:parent_event).optional }
      it { is_expected.to have_many(:child_events).dependent(:destroy) }
    end

    describe '#create_recurrence_schedule' do
      it 'creates a daily recurrence schedule' do
        schedule = event.create_recurrence_schedule(rule: :daily, interval: 1)

        expect(event.is_recurring).to be true
        expect(event.recurrence_rule).to be_present
        expect(schedule).to be_a(IceCube::Schedule)
      end

      it 'creates a weekly recurrence schedule with interval' do
        schedule = event.create_recurrence_schedule(rule: :weekly, interval: 2)

        expect(event.is_recurring).to be true
        expect(schedule.to_s).to include('Weekly')
      end

      it 'creates a monthly recurrence schedule' do
        schedule = event.create_recurrence_schedule(rule: :monthly)

        expect(event.is_recurring).to be true
        expect(schedule.to_s).to include('Monthly')
      end

      it 'creates a yearly recurrence schedule' do
        schedule = event.create_recurrence_schedule(rule: :yearly)

        expect(event.is_recurring).to be true
        expect(schedule.to_s).to include('Yearly')
      end

      it 'supports until_date parameter' do
        until_date = 1.year.from_now
        event.create_recurrence_schedule(rule: :daily, until_date: until_date)

        schedule = event.schedule
        expect(schedule.occurrences_between(Time.current, 2.years.from_now).last.to_date)
          .to be <= until_date.to_date
      end

      it 'supports count parameter' do
        event.create_recurrence_schedule(rule: :daily, count: 5)

        schedule = event.schedule
        occurrences = schedule.occurrences_between(event.starts_at, 1.year.from_now)
        expect(occurrences.count).to eq(5)
      end

      it 'raises error for invalid rule type' do
        expect do
          event.create_recurrence_schedule(rule: :invalid)
        end.to raise_error(ArgumentError, /Invalid recurrence rule/)
      end
    end

    describe '#schedule' do
      context 'when event is not recurring' do
        it 'returns nil' do
          expect(event.schedule).to be_nil
        end
      end

      context 'when event is recurring' do
        before do
          event.create_recurrence_schedule(rule: :daily)
          event.save!
        end

        it 'returns an IceCube::Schedule object' do
          expect(event.schedule).to be_a(IceCube::Schedule)
        end

        it 'memoizes the schedule' do
          schedule1 = event.schedule
          schedule2 = event.schedule

          expect(schedule1.object_id).to eq(schedule2.object_id)
        end
      end
    end

    describe '#occurrences_between' do
      context 'when event is not recurring' do
        it 'returns array with only the event itself' do
          occurrences = event.occurrences_between(1.week.ago, 1.week.from_now)

          expect(occurrences).to eq([event])
        end
      end

      context 'when event is recurring' do
        before do
          event.create_recurrence_schedule(rule: :daily, count: 10)
          event.save!
        end

        it 'returns EventOccurrence objects' do
          occurrences = event.occurrences_between(event.starts_at, 5.days.from_now)

          expect(occurrences).to all(be_a(BetterTogether::EventOccurrence))
        end

        it 'returns occurrences within the date range' do
          occurrences = event.occurrences_between(event.starts_at, 5.days.from_now)

          expect(occurrences.count).to eq(5)
        end

        it 'respects the recurrence rule' do
          occurrences = event.occurrences_between(event.starts_at, 3.days.from_now)

          occurrences.each_with_index do |occurrence, index|
            expected_time = event.starts_at + index.days
            expect(occurrence.starts_at.to_date).to eq(expected_time.to_date)
          end
        end
      end
    end

    describe '#next_occurrence' do
      context 'when event is not recurring' do
        it 'returns nil' do
          expect(event.next_occurrence).to be_nil
        end
      end

      context 'when event is recurring' do
        before do
          event.create_recurrence_schedule(rule: :daily, count: 10)
          event.save!
        end

        it 'returns the next occurrence after current time' do
          next_occ = event.next_occurrence

          expect(next_occ).to be > Time.current
        end

        it 'accepts custom after parameter' do
          after_time = event.starts_at + 3.days
          next_occ = event.next_occurrence(after: after_time)

          expect(next_occ).to be > after_time
        end
      end
    end

    describe '#exception_date?' do
      it 'returns false when no exception dates exist' do
        expect(event.exception_date?(Date.today)).to be false
      end

      it 'returns true when date is in exception list' do
        exception_date = Date.today
        event.recurrence_exception_dates = [exception_date]

        expect(event.exception_date?(exception_date)).to be true
      end

      it 'returns false when date is not in exception list' do
        event.recurrence_exception_dates = [Date.yesterday]

        expect(event.exception_date?(Date.today)).to be false
      end
    end

    describe '#add_exception_date' do
      it 'adds a date to the exception list' do
        date = Date.today
        event.add_exception_date(date)

        expect(event.recurrence_exception_dates).to include(date)
      end

      it 'does not add duplicate dates' do
        date = Date.today
        event.add_exception_date(date)
        event.add_exception_date(date)

        expect(event.recurrence_exception_dates.count(date)).to eq(1)
      end

      it 'initializes exception_dates if nil' do
        event.recurrence_exception_dates = nil
        event.add_exception_date(Date.today)

        expect(event.recurrence_exception_dates).to be_an(Array)
      end
    end

    describe '#remove_exception_date' do
      it 'removes a date from the exception list' do
        date = Date.today
        event.recurrence_exception_dates = [date]

        event.remove_exception_date(date)

        expect(event.recurrence_exception_dates).not_to include(date)
      end

      it 'handles nil exception_dates gracefully' do
        event.recurrence_exception_dates = nil

        expect { event.remove_exception_date(Date.today) }.not_to raise_error
      end
    end
  end
end
