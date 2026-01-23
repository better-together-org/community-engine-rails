# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe EventsHelper do
    let(:event) { create(:better_together_event, starts_at: start_time, ends_at: end_time, timezone: 'UTC') }
    let(:start_time) { Time.zone.parse('2025-09-04 14:00:00') } # 2:00 PM

    before do
      configure_host_platform
    end

    describe '#display_event_time' do
      context 'when event has no start time' do
        let(:event) { create(:better_together_event, starts_at: nil, ends_at: nil) }

        it 'returns empty string' do
          expect(helper.display_event_time(event)).to eq('')
        end
      end

      context 'when event has no end time' do
        let(:event) { build(:better_together_event, starts_at: start_time, ends_at: nil, duration_minutes: nil, timezone: 'UTC') }

        it 'returns formatted start time only' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2025 2:00 PM')
        end
      end

      context 'when event has no end time and is in a different year' do
        let(:start_time) { Time.zone.parse('2024-09-04 14:00:00') } # Different year
        let(:event) { build(:better_together_event, starts_at: start_time, ends_at: nil, duration_minutes: nil, timezone: 'UTC') }

        it 'returns formatted start time with year' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2024 2:00 PM')
        end
      end

      context 'when duration is under 1 hour' do
        let(:end_time) { start_time + 30.minutes } # 2:30 PM

        it 'displays start time with minutes duration' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2025 2:00 PM (30 minutes)')
        end
      end

      context 'when duration is under 1 hour and in different year' do
        let(:start_time) { Time.zone.parse('2024-09-04 14:00:00') } # Different year
        let(:end_time) { start_time + 30.minutes } # 2:30 PM

        it 'displays start time with year and minutes duration' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2024 2:00 PM (30 minutes)')
        end
      end

      context 'when duration is exactly 1 hour' do
        let(:end_time) { start_time + 1.hour } # 3:00 PM

        it 'displays start time with hour duration (singular)' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2025 2:00 PM (1 hour)')
        end
      end

      context 'when duration is between 1 and 5 hours on same day' do
        let(:end_time) { start_time + 3.hours } # 5:00 PM

        it 'displays start time with hours duration (plural)' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2025 2:00 PM (3 hours)')
        end
      end

      context 'when duration is exactly 5 hours on same day' do
        let(:end_time) { start_time + 5.hours } # 7:00 PM

        it 'displays start time with hours duration' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2025 2:00 PM (5 hours)')
        end
      end

      context 'when duration is over 5 hours on same day' do
        let(:end_time) { start_time + 6.hours } # 8:00 PM

        it 'displays start and end times' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2025 2:00 PM - 8:00 PM 2025')
        end
      end

      context 'when duration is over 5 hours on same day in different year' do
        let(:start_time) { Time.zone.parse('2024-09-04 14:00:00') } # Different year
        let(:end_time) { start_time + 6.hours } # 8:00 PM

        it 'displays start and end times with year' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2024 2:00 PM - 8:00 PM 2024')
        end
      end

      context 'when event spans multiple days' do
        let(:end_time) { start_time + 1.day + 2.hours } # Next day at 4:00 PM

        it 'displays full start and end date times' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2025 2:00 PM - Sep 5, 2025 4:00 PM')
        end
      end

      context 'when event spans multiple days with short duration' do
        let(:end_time) { start_time + 1.day + 30.minutes } # Next day at 2:30 PM

        it 'displays full start and end date times (ignores duration rules for multi-day)' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2025 2:00 PM - Sep 5, 2025 2:30 PM')
        end
      end

      context 'when event spans multiple days in different year' do
        let(:start_time) { Time.zone.parse('2024-09-04 14:00:00') } # Different year
        let(:end_time) { start_time + 1.day + 2.hours } # Next day at 4:00 PM

        it 'displays full start and end date times with year' do
          expect(helper.display_event_time(event)).to eq('Sep 4, 2024 2:00 PM - Sep 5, 2024 4:00 PM')
        end
      end

      context 'when event spans into next year' do
        let(:start_time) { Time.zone.parse('2024-12-31 22:00:00') } # Dec 31, 2024
        let(:end_time) { start_time + 4.hours } # Jan 1, 2025

        it 'displays both dates with their respective years' do
          expect(helper.display_event_time(event)).to eq('Dec 31, 2024 10:00 PM - Jan 1, 2025 2:00 AM')
        end
      end
    end

    describe '#visible_event_hosts' do
      it 'handles events without event_hosts method' do
        event = double('event') # rubocop:todo RSpec/VerifiedDoubles
        allow(event).to receive(:respond_to?).with(:event_hosts).and_return(false)
        expect(helper.visible_event_hosts(event)).to eq([])
      end
    end
  end
end
