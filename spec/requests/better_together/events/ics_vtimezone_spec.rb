# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event ICS Export with VTIMEZONE' do
  let(:platform) { BetterTogether::Platform.host.first }
  let(:community) { platform.community }
  let(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
  let(:person) { user.person }

  before do
    platform.update!(time_zone: 'America/Toronto')
  end

  describe 'GET /events/:id.ics', :as_user do
    context 'with timezone-aware event' do
      let(:event) do
        tokyo_tz = ActiveSupport::TimeZone['Asia/Tokyo']
        create(:event,
               name: 'Tokyo Tech Conference',
               timezone: 'Asia/Tokyo',
               starts_at: tokyo_tz.parse('2026-03-15 14:00:00'),
               ends_at: tokyo_tz.parse('2026-03-15 16:00:00'),
               creator: person)
      end

      before do
        create(:better_together_event_host, event: event, host: community)
      end

      it 'includes VTIMEZONE component in ICS export' do
        get event_path(event, format: :ics, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/calendar')
        expect(response.body).to include('BEGIN:VTIMEZONE')
        expect(response.body).to include('END:VTIMEZONE')
      end

      it 'includes timezone identifier in VTIMEZONE' do
        get event_path(event, format: :ics, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('TZID:Asia/Tokyo')
      end

      it 'uses TZID parameter in DTSTART and DTEND' do
        get event_path(event, format: :ics, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        # Times should use TZID parameter instead of UTC format
        expect(response.body).to include('DTSTART;TZID=Asia/Tokyo:20260315T140000')
        expect(response.body).to include('DTEND;TZID=Asia/Tokyo:20260315T160000')
        # Should NOT use UTC format for timezone-aware events
        expect(response.body).not_to include('DTSTART:20260315T050000Z')
      end

      it 'includes standard timezone offset information' do
        get event_path(event, format: :ics, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        # Tokyo uses JST (UTC+9) year-round, no DST
        expect(response.body).to include('BEGIN:STANDARD')
        expect(response.body).to include('TZOFFSETFROM:+0900')
        expect(response.body).to include('TZOFFSETTO:+0900')
      end
    end

    context 'with DST-observing timezone' do
      let(:event) do
        ny_tz = ActiveSupport::TimeZone['America/New_York']
        create(:event,
               name: 'NYC Summer Event',
               timezone: 'America/New_York',
               starts_at: ny_tz.parse('2026-07-15 10:00:00'), # During EDT
               ends_at: ny_tz.parse('2026-07-15 12:00:00'),
               creator: person)
      end

      before do
        create(:better_together_event_host, event: event, host: community)
      end

      it 'includes DST transition rules' do
        get event_path(event, format: :ics, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        # NYC observes DST, should include DAYLIGHT component
        expect(response.body).to include('BEGIN:DAYLIGHT')
        expect(response.body).to include('END:DAYLIGHT')
      end

      it 'includes correct offset for daylight saving time' do
        get event_path(event, format: :ics, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        # EDT is UTC-4 (from EST UTC-5)
        expect(response.body).to match(/TZOFFSETTO:-0[45]00/)
      end
    end

    context 'with event in UTC timezone' do
      let(:event) do
        utc_tz = ActiveSupport::TimeZone['UTC']
        create(:event,
               name: 'Global Virtual Event',
               timezone: 'UTC',
               starts_at: utc_tz.parse('2026-05-20 15:00:00'),
               ends_at: utc_tz.parse('2026-05-20 17:00:00'),
               creator: person)
      end

      before do
        create(:better_together_event_host, event: event, host: community)
      end

      it 'uses UTC time format without VTIMEZONE' do
        get event_path(event, format: :ics, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        # UTC events use Z suffix, no VTIMEZONE needed
        expect(response.body).to include('DTSTART:20260520T150000Z')
        expect(response.body).to include('DTEND:20260520T170000Z')
        expect(response.body).not_to include('BEGIN:VTIMEZONE')
      end
    end
  end

  describe 'ICS calendar compatibility', :as_user do
    let(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
    let(:person) { user.person }

    let(:event) do
      london_tz = ActiveSupport::TimeZone['Europe/London']
      create(:event,
             name: 'London Workshop',
             timezone: 'Europe/London',
             starts_at: london_tz.parse('2026-04-10 14:00:00'),
             ends_at: london_tz.parse('2026-04-10 17:00:00'),
             creator: person)
    end

    before do
      create(:better_together_event_host, event: event, host: community)
    end

    it 'generates valid ICS structure' do
      get event_path(event, format: :ics, locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      ics_content = response.body

      # Verify proper ICS structure
      expect(ics_content).to match(/BEGIN:VCALENDAR.*END:VCALENDAR/m)
      expect(ics_content).to include('VERSION:2.0')
      expect(ics_content).to include('PRODID:-//Better Together Community Engine//EN')

      # VTIMEZONE must come before VEVENT
      vtimezone_pos = ics_content.index('BEGIN:VTIMEZONE')
      vevent_pos = ics_content.index('BEGIN:VEVENT')
      expect(vtimezone_pos).to be < vevent_pos
    end

    it 'uses proper line endings' do
      get event_path(event, format: :ics, locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      # ICS files must use CRLF line endings
      expect(response.body).to include("\r\n")
      expect(response.body).not_to match(/(?<!\r)\n/)
    end

    it 'sets correct content type and disposition' do
      get event_path(event, format: :ics, locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/calendar')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end
  end
end
