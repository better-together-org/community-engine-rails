# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CalendarsController', :as_user do
  let(:locale) { I18n.default_locale }

  it 'renders index' do
    get better_together.calendars_path(locale:)
    expect(response).to have_http_status(:ok)
  end

  context 'when viewing calendar show page' do
    let(:calendar) { create('better_together/calendar', privacy: 'public') }
    let(:upcoming_event) do
      BetterTogether::Event.create!(
        name: 'Upcoming',
        starts_at: 2.days.from_now,
        identifier: SecureRandom.uuid
      )
    end
    let(:past_event) do
      BetterTogether::Event.create!(
        name: 'Past',
        starts_at: 3.days.ago,
        identifier: SecureRandom.uuid
      )
    end

    before do
      BetterTogether::CalendarEntry.create!(calendar:, event: upcoming_event, starts_at: upcoming_event.starts_at)
      BetterTogether::CalendarEntry.create!(calendar:, event: past_event, starts_at: past_event.starts_at)
    end

    it 'renders successfully' do
      get better_together.calendar_path(calendar, locale:)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /calendars/:id/feed' do
    let(:community) { create(:community) }
    let(:calendar) { create('better_together/calendar', community:, privacy: 'private') }
    let(:first_event) do
      create(:event,
             name: 'First Event',
             starts_at: 1.week.from_now,
             ends_at: 1.week.from_now + 1.hour,
             timezone: 'America/New_York')
    end
    let(:second_event) do
      create(:event,
             name: 'Second Event',
             starts_at: 2.weeks.from_now,
             ends_at: 2.weeks.from_now + 2.hours,
             timezone: 'America/Los_Angeles')
    end

    before do
      BetterTogether::CalendarEntry.create!(calendar:, event: first_event, starts_at: first_event.starts_at)
      BetterTogether::CalendarEntry.create!(calendar:, event: second_event, starts_at: second_event.starts_at)
    end

    context 'with valid subscription token' do
      it 'returns ICS format calendar feed' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/calendar')
      end

      it 'includes all events in the feed' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)

        expect(response.body).to include('SUMMARY:First Event')
        expect(response.body).to include('SUMMARY:Second Event')
      end

      it 'includes proper calendar structure' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)

        expect(response.body).to include('BEGIN:VCALENDAR')
        expect(response.body).to include('END:VCALENDAR')
        expect(response.body).to include('VERSION:2.0')
        expect(response.body).to include('PRODID:-//Better Together Community Engine//EN')
      end

      it 'sets inline disposition with calendar slug as filename' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)

        expect(response.headers['Content-Disposition']).to include('inline')
        expect(response.headers['Content-Disposition']).to include("#{calendar.slug}.ics")
      end

      it 'returns JSON format calendar feed' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :json)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
      end

      it 'includes valid JSON structure' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :json)

        json = JSON.parse(response.body)
        expect(json['kind']).to eq('calendar#events')
        expect(json['summary']).to eq('Better Together Events')
        expect(json['items']).to be_an(Array)
        expect(json['items'].length).to eq(2)
      end

      it 'includes all events in JSON format' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :json)

        json = JSON.parse(response.body)
        event_names = json['items'].map { |item| item['summary'] }
        expect(event_names).to contain_exactly('First Event', 'Second Event')
      end

      it 'sets JSON disposition with calendar slug as filename' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :json)

        expect(response.headers['Content-Disposition']).to include('inline')
        expect(response.headers['Content-Disposition']).to include("#{calendar.slug}.json")
      end
    end

    context 'with invalid subscription token' do
      it 'returns not found status to avoid leaking resource existence' do
        get better_together.feed_calendar_path(calendar, locale:, token: 'invalid-token', format: :ics)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without subscription token for private calendar' do
      it 'returns unauthorized status', :no_auth do
        get better_together.feed_calendar_path(calendar, locale:, format: :ics)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with public calendar and no token' do
      before { calendar.update!(privacy: 'public') }

      it 'returns feed for authenticated users', :as_user do
        get better_together.feed_calendar_path(calendar, locale:, format: :ics)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/calendar')
      end

      it 'requires authentication for public calendars without token', :no_auth do
        get better_together.feed_calendar_path(calendar, locale:, format: :ics)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
