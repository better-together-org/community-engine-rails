# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe CalendarEntry do
    describe 'factory' do
      it 'creates a valid calendar entry' do
        calendar_entry = create(:calendar_entry)
        expect(calendar_entry).to be_valid
        expect(calendar_entry.calendar).to be_present
        expect(calendar_entry.event).to be_present
        expect(calendar_entry.starts_at).to be_present
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:calendar).class_name('BetterTogether::Calendar') }
      it { is_expected.to belong_to(:event).class_name('BetterTogether::Event') }
    end

    describe 'validations' do
      describe 'uniqueness' do
        it 'validates event_id uniqueness scoped to calendar_id' do
          calendar = create(:calendar)
          event = create(:event)

          create(:calendar_entry, calendar: calendar, event: event)
          duplicate = build(:calendar_entry, calendar: calendar, event: event)

          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:event_id]).to include('has already been taken')
        end

        it 'allows same event in different calendars' do
          event = create(:event)
          calendar1 = create(:calendar)
          calendar2 = create(:calendar)

          entry1 = create(:calendar_entry, calendar: calendar1, event: event)
          entry2 = build(:calendar_entry, calendar: calendar2, event: event)

          expect(entry1).to be_valid
          expect(entry2).to be_valid
        end

        it 'allows different events in same calendar' do
          calendar = create(:calendar)
          event1 = create(:event)
          event2 = create(:event)

          entry1 = create(:calendar_entry, calendar: calendar, event: event1)
          entry2 = build(:calendar_entry, calendar: calendar, event: event2)

          expect(entry1).to be_valid
          expect(entry2).to be_valid
        end
      end
    end

    describe 'scheduling attributes' do
      it 'tracks start and end times' do
        starts = 1.week.from_now
        ends = starts + 2.hours

        entry = create(:calendar_entry, starts_at: starts, ends_at: ends)

        expect(entry.starts_at).to be_within(1.second).of(starts)
        expect(entry.ends_at).to be_within(1.second).of(ends)
      end

      it 'tracks duration in minutes' do
        entry = create(:calendar_entry, duration_minutes: 90)
        expect(entry.duration_minutes).to eq(90)
      end

      it 'allows nil ends_at' do
        entry = create(:calendar_entry, ends_at: nil)
        expect(entry.ends_at).to be_nil
        expect(entry).to be_valid
      end
    end

    describe 'join model behavior' do
      it 'links calendar and event' do
        calendar = create(:calendar)
        event = create(:event)
        calendar_entry = create(:calendar_entry, calendar: calendar, event: event)

        expect(calendar_entry.calendar).to eq(calendar)
        expect(calendar_entry.event).to eq(event)
      end
    end
  end
end
