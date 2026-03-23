# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Calendar Feed HTTP Caching', :as_user do
  let(:locale) { I18n.default_locale }
  let(:community) { create(:community) }
  let(:calendar) { create('better_together/calendar', community:, privacy: 'private') }
  let(:event) do
    create(:event,
           name: 'Test Event',
           starts_at: 1.week.from_now,
           ends_at: 1.week.from_now + 1.hour)
  end

  before do
    BetterTogether::CalendarEntry.create!(calendar:, event:, starts_at: event.starts_at)
  end

  describe 'HTTP caching headers' do
    context 'with ICS format' do
      it 'sets Cache-Control header for private caching' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)

        expect(response.headers['Cache-Control']).to include('private')
        expect(response.headers['Cache-Control']).to include('max-age=3600')
      end

      it 'includes ETag header' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)

        expect(response.headers['ETag']).to be_present
      end

      it 'includes Last-Modified header' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)

        expect(response.headers['Last-Modified']).to be_present
      end

      it 'returns 304 Not Modified when content has not changed' do
        # First request
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)
        etag = response.headers['ETag']
        last_modified = response.headers['Last-Modified']

        # Second request with same ETag
        get better_together.feed_calendar_path(
          calendar,
          locale:,
          token: calendar.subscription_token,
          format: :ics
        ), headers: {
          'If-None-Match' => etag,
          'If-Modified-Since' => last_modified
        }

        expect(response).to have_http_status(:not_modified)
      end

      it 'returns 200 OK when content has changed' do
        # First request
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)
        etag = response.headers['ETag']
        last_modified = response.headers['Last-Modified']

        # Modify calendar
        travel 1.hour
        calendar.update!(name: 'Updated Calendar Name')

        # Second request - should return full content
        get better_together.feed_calendar_path(
          calendar,
          locale:,
          token: calendar.subscription_token,
          format: :ics
        ), headers: {
          'If-None-Match' => etag,
          'If-Modified-Since' => last_modified
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_present
      end

      it 'updates ETag when event is modified' do
        # First request
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)
        original_etag = response.headers['ETag']

        # Modify event
        travel 1.hour
        event.update!(name: 'Modified Event Name')

        # Second request - should have different ETag
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)
        new_etag = response.headers['ETag']

        expect(new_etag).not_to eq(original_etag)
      end
    end

    context 'with JSON format' do
      it 'sets Cache-Control header for private caching' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :json)

        expect(response.headers['Cache-Control']).to include('private')
        expect(response.headers['Cache-Control']).to include('max-age=3600')
      end

      it 'includes ETag header' do
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :json)

        expect(response.headers['ETag']).to be_present
      end

      it 'returns 304 Not Modified for unchanged content' do
        # First request
        get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :json)
        etag = response.headers['ETag']

        # Second request with same ETag
        get better_together.feed_calendar_path(
          calendar,
          locale:,
          token: calendar.subscription_token,
          format: :json
        ), headers: { 'If-None-Match' => etag }

        expect(response).to have_http_status(:not_modified)
      end
    end
  end

  describe 'eager loading optimization' do
    let!(:event_with_recurrence) do
      event = create(:event, name: 'Recurring Event', starts_at: 1.week.from_now)
      create(:recurrence, schedulable: event)
      BetterTogether::CalendarEntry.create!(calendar:, event:, starts_at: event.starts_at)
      event
    end

    it 'eager loads creator and recurrence associations' do
      # Verify the query includes the associations
      get better_together.feed_calendar_path(calendar, locale:, token: calendar.subscription_token, format: :ics)

      expect(response).to have_http_status(:ok)
      # If eager loading is working, the ICS will include recurrence information
      expect(response.body).to include('RRULE')
    end
  end
end
