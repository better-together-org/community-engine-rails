# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Event timezone helpers' do
  let(:event) do
    create(:better_together_event,
           timezone: 'America/New_York',
           starts_at: Time.utc(2026, 6, 15, 18, 0, 0), # 6:00 PM UTC
           ends_at: Time.utc(2026, 6, 15, 20, 0, 0))   # 8:00 PM UTC
  end

  describe '#local_starts_at' do
    it 'returns starts_at in event timezone' do
      # 6:00 PM UTC = 2:00 PM EDT (America/New_York in June)
      expect(event.local_starts_at.hour).to eq(14)
      expect(event.local_starts_at.zone).to eq('EDT')
    end

    it 'handles different timezones' do
      event.update!(timezone: 'Asia/Tokyo')
      # 6:00 PM UTC = 3:00 AM JST next day
      expect(event.local_starts_at.hour).to eq(3)
      expect(event.local_starts_at.day).to eq(16)
    end

    it 'returns nil when starts_at is nil' do
      event.update!(starts_at: nil)
      expect(event.local_starts_at).to be_nil
    end
  end

  describe '#local_ends_at' do
    it 'returns ends_at in event timezone' do
      # 8:00 PM UTC = 4:00 PM EDT
      expect(event.local_ends_at.hour).to eq(16)
      expect(event.local_ends_at.zone).to eq('EDT')
    end

    it 'returns nil when starts_at is nil' do
      event.update!(starts_at: nil, ends_at: nil, duration_minutes: nil)
      expect(event.local_ends_at).to be_nil
    end
  end

  describe '#starts_at_in_zone' do
    it 'returns starts_at in specified timezone' do
      # 6:00 PM UTC in Los Angeles time (PDT in June)
      la_time = event.starts_at_in_zone('America/Los_Angeles')
      expect(la_time.hour).to eq(11) # 11:00 AM PDT
      expect(la_time.zone).to eq('PDT')
    end

    it 'returns nil when starts_at is nil' do
      event.update!(starts_at: nil)
      expect(event.starts_at_in_zone('America/Chicago')).to be_nil
    end
  end

  describe '#ends_at_in_zone' do
    it 'returns ends_at in specified timezone' do
      # 8:00 PM UTC in Los Angeles time
      la_time = event.ends_at_in_zone('America/Los_Angeles')
      expect(la_time.hour).to eq(13) # 1:00 PM PDT
    end

    it 'returns nil when starts_at is nil' do
      event.update!(starts_at: nil, ends_at: nil, duration_minutes: nil)
      expect(event.ends_at_in_zone('America/Chicago')).to be_nil
    end
  end

  describe '#timezone_display' do
    it 'returns human-friendly timezone name' do
      display = event.timezone_display
      expect(display).to include('America/New_York')
    end

    it 'handles different timezones' do
      event.update!(timezone: 'Europe/London')
      display = event.timezone_display
      expect(display).to include('London')
    end

    it 'falls back to IANA identifier if no Rails timezone found' do
      event.update!(timezone: 'America/St_Johns')
      display = event.timezone_display
      # Should include the IANA identifier
      expect(display).to include('America/St_Johns')
    end
  end

  describe 'DST transitions' do
    context 'during spring forward' do
      let(:dst_event) do
        create(:better_together_event,
               timezone: 'America/New_York',
               # March 10, 2026 at 3:00 AM EDT doesn't exist (skipped)
               starts_at: Time.utc(2026, 3, 10, 7, 30, 0), # 2:30 AM EST becomes 3:30 AM EDT
               ends_at: Time.utc(2026, 3, 10, 9, 30, 0))   # Add end time
      end

      it 'handles DST transition correctly' do
        local_time = dst_event.local_starts_at
        expect(local_time.zone).to eq('EDT')
        expect(local_time.hour).to eq(3)
      end
    end

    context 'during fall back' do
      let(:fallback_event) do
        create(:better_together_event,
               timezone: 'America/New_York',
               # November 2, 2026 at 1:30 AM EST (after falling back from EDT)
               starts_at: Time.utc(2026, 11, 2, 6, 30, 0), # 1:30 AM EST
               ends_at: Time.utc(2026, 11, 2, 8, 30, 0))   # 3:30 AM EST
      end

      it 'handles fall back transition' do
        local_time = fallback_event.local_starts_at
        expect(local_time.hour).to eq(1)
        expect(local_time.zone).to eq('EST')
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
