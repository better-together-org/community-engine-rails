# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe EventsHelper, type: :helper do
    describe '#event_time_range' do
      let(:start_time) { Time.zone.parse('2024-03-10 15:00') }
      let(:event) { instance_double(Event, starts_at: start_time, ends_at: end_time) }

      context 'when end time is on same day' do
        let(:end_time) { Time.zone.parse('2024-03-10 17:00') }

        it 'formats with end time only' do
          expected = "#{I18n.l(start_time, format: :event)} - #{I18n.l(end_time, format: '%-I:%M %p')}"
          expect(helper.event_time_range(event)).to eq(expected)
        end
      end

      context 'when end time is on a different day' do
        let(:end_time) { Time.zone.parse('2024-03-11 17:00') }

        it 'formats both start and end times fully' do
          expected = "#{I18n.l(start_time, format: :event)} - #{I18n.l(end_time, format: :event)}"
          expect(helper.event_time_range(event)).to eq(expected)
        end
      end

      context 'without an end time' do
        let(:end_time) { nil }

        it 'returns only the start time' do
          expect(helper.event_time_range(event)).to eq(I18n.l(start_time, format: :event))
        end
      end
    end

    describe '#event_location' do
      it 'combines name and location' do
        locatable = instance_double(
          Geography::LocatableLocation,
          name: 'Town Hall',
          location: 'Springfield'
        )
        event = instance_double(Event, location: locatable)

        expect(helper.event_location(event)).to eq('Town Hall, Springfield')
      end

      it 'returns nil when no location is present' do
        expect(helper.event_location(instance_double(Event, location: nil))).to be_nil
      end
    end
  end
end
