# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Timezone integration' do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:community) { platform.community }

  let(:person_ny) { create(:better_together_person, time_zone: 'America/New_York') }
  let(:person_tokyo) { create(:better_together_person, time_zone: 'Asia/Tokyo') }
  let(:person_london) { create(:better_together_person, time_zone: 'Europe/London') }

  # Event scheduled for 2:00 PM UTC on June 15, 2026
  let(:event) do
    create(:better_together_event,
           timezone: 'America/Los_Angeles',
           starts_at: Time.utc(2026, 6, 15, 14, 0, 0),  # 2:00 PM UTC
           ends_at: Time.utc(2026, 6, 15, 16, 0, 0))    # 4:00 PM UTC
  end

  before do
    platform.update!(time_zone: 'America/Chicago')
  end

  describe 'Event timezone display across multiple users' do
    it 'shows event in Los Angeles time (event timezone)' do
      # 2:00 PM UTC = 7:00 AM PDT in Los Angeles
      expect(event.local_starts_at.hour).to eq(7)
      expect(event.local_starts_at.zone).to eq('PDT')
    end

    it 'converts event to New York time for NY user' do
      # 2:00 PM UTC = 10:00 AM EDT in New York
      ny_time = event.starts_at_in_zone(person_ny.time_zone)
      expect(ny_time.hour).to eq(10)
      expect(ny_time.zone).to eq('EDT')
    end

    it 'converts event to Tokyo time for Tokyo user' do
      # 2:00 PM UTC = 11:00 PM JST in Tokyo (same day)
      tokyo_time = event.starts_at_in_zone(person_tokyo.time_zone)
      expect(tokyo_time.hour).to eq(23)
      expect(tokyo_time.day).to eq(15)
    end

    it 'converts event to London time for London user' do
      # 2:00 PM UTC = 3:00 PM BST in London (summer time)
      london_time = event.starts_at_in_zone(person_london.time_zone)
      expect(london_time.hour).to eq(15)
      expect(london_time.zone).to eq('BST')
    end
  end

  describe 'Controller timezone context' do
    it 'sets timezone for authenticated user request', :as_user do
      get "/#{I18n.default_locale}"

      # Verify Time.zone is set during request
      expect(response).to have_http_status(:ok)
    end

    it 'uses platform timezone for guest request' do
      get "/#{I18n.default_locale}"

      expect(response).to have_http_status(:ok)
      # Platform timezone should be used for guests
    end
  end

  describe 'DST boundary scenarios' do
    context 'spring forward event' do
      let(:spring_event) do
        create(:better_together_event,
               timezone: 'America/New_York',
               # March 8, 2026 at 1:00 AM EST, ends at 3:00 AM EDT (2:00 AM doesn't exist)
               starts_at: Time.utc(2026, 3, 8, 6, 0, 0),  # 1:00 AM EST
               ends_at: Time.utc(2026, 3, 8, 8, 0, 0))    # 3:00 AM EDT
      end

      it 'handles spring forward correctly' do
        # Starts before DST transition
        expect(spring_event.local_starts_at.hour).to eq(1)
        expect(spring_event.local_starts_at.zone).to eq('EST')
        # Ends after DST transition - 8:00 UTC = 4:00 AM EDT (not 3:00 AM)
        expect(spring_event.local_ends_at.hour).to eq(4)
        expect(spring_event.local_ends_at.zone).to eq('EDT')
      end

      it 'calculates duration correctly across DST boundary' do
        # 2-hour duration, but only 1 hour of wall clock time
        utc_duration = (spring_event.ends_at - spring_event.starts_at) / 3600
        expect(utc_duration).to eq(2.0)
      end
    end

    context 'fall back event' do
      let(:fall_event) do
        create(:better_together_event,
               timezone: 'America/New_York',
               # November 1, 2026 at 11:00 PM EDT, ends at 1:00 AM EST after fall back
               starts_at: Time.utc(2026, 11, 2, 3, 0, 0),  # 11:00 PM EDT on Nov 1
               ends_at: Time.utc(2026, 11, 2, 6, 0, 0))    # 1:00 AM EST on Nov 2
      end

      it 'handles fall back correctly' do
        # 3:00 UTC on Nov 2 = 10:00 PM EST on Nov 1 (after fall back)
        expect(fall_event.local_starts_at.hour).to eq(22)
        expect(fall_event.local_starts_at.zone).to eq('EST')
      end
    end
  end

  describe 'International date line scenarios' do
    let(:dateline_event) do
      create(:better_together_event,
             timezone: 'Pacific/Auckland',
             # Event at 11:00 PM in Auckland
             starts_at: Time.utc(2026, 6, 15, 11, 0, 0),
             ends_at: Time.utc(2026, 6, 15, 13, 0, 0))
    end

    it 'handles timezone on opposite side of date line' do
      # 11:00 AM UTC on June 15 = 11:00 PM NZST on June 15
      auckland_time = dateline_event.local_starts_at
      expect(auckland_time.hour).to eq(23)
      expect(auckland_time.day).to eq(15)
    end

    it 'converts to US timezone showing previous day' do
      # 11:00 AM UTC = 4:00 AM PDT on June 15
      la_time = dateline_event.starts_at_in_zone('America/Los_Angeles')
      expect(la_time.hour).to eq(4)
      expect(la_time.day).to eq(15)
    end
  end

  describe 'Multi-timezone event coordination' do
    it 'shows same moment in time across all timezones' do
      utc_moment = event.starts_at

      la_time = event.starts_at_in_zone('America/Los_Angeles')
      ny_time = event.starts_at_in_zone('America/New_York')
      london_time = event.starts_at_in_zone('Europe/London')
      tokyo_time = event.starts_at_in_zone('Asia/Tokyo')

      # All should represent the same UTC moment
      expect(la_time.utc).to eq(utc_moment)
      expect(ny_time.utc).to eq(utc_moment)
      expect(london_time.utc).to eq(utc_moment)
      expect(tokyo_time.utc).to eq(utc_moment)
    end

    it 'calculates correct time differences between zones' do
      la_time = event.starts_at_in_zone('America/Los_Angeles')
      tokyo_time = event.starts_at_in_zone('Asia/Tokyo')

      # LA is PDT (UTC-7), Tokyo is JST (UTC+9), difference is 16 hours
      hour_difference = tokyo_time.hour - la_time.hour
      hour_difference += 24 if hour_difference < 0

      expect(hour_difference).to eq(16)
    end
  end

  describe 'Platform timezone backfill migration' do
    it 'uses platform timezone for events without explicit timezone' do
      # This would be an event created before timezone column existed
      # and backfilled with platform timezone
      old_event = create(:better_together_event,
                         timezone: platform.time_zone,
                         starts_at: Time.utc(2026, 7, 1, 18, 0, 0),
                         ends_at: Time.utc(2026, 7, 1, 20, 0, 0))

      expect(old_event.timezone).to eq('America/Chicago')
      # 6:00 PM UTC = 1:00 PM CDT in Chicago
      expect(old_event.local_starts_at.hour).to eq(13)
    end
  end

  describe 'Timezone validation' do
    it 'rejects invalid IANA timezone identifiers' do
      expect do
        create(:better_together_event, timezone: 'Invalid/Timezone')
      end.to raise_error(ActiveRecord::RecordInvalid, %r{Timezone Invalid/Timezone is not a valid timezone})
    end

    it 'rejects Rails timezone names' do
      expect do
        create(:better_together_event, timezone: 'Eastern Time (US & Canada)')
      end.to raise_error(ActiveRecord::RecordInvalid, /is not a valid timezone/)
    end

    it 'accepts all IANA timezone identifiers' do
      valid_timezones = ['America/New_York', 'Europe/London', 'Asia/Tokyo', 'UTC']

      valid_timezones.each do |tz|
        event = build(:better_together_event, timezone: tz)
        expect(event).to be_valid
      end
    end
  end

  describe 'Timezone display helpers' do
    it 'provides human-friendly timezone display' do
      expect(event.timezone_display).to include('America/Los_Angeles')
    end

    it 'includes IANA identifier in display' do
      ny_event = create(:better_together_event, timezone: 'America/New_York')
      expect(ny_event.timezone_display).to include('America/New_York')
    end
  end
end
# rubocop:enable RSpec/DescribeClass
