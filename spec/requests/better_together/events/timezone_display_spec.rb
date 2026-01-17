# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event Timezone Display' do
  let(:platform) { BetterTogether::Platform.host.first }
  let(:community) { platform.community }

  before do
    platform.update!(time_zone: 'America/Toronto')
  end

  describe 'GET /events/:id (show page)', :as_user do
    let(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
    let(:person) { user.person }

    let(:event) do
      # Create event with times in Tokyo timezone
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

    it 'displays event timezone name' do
      get event_path(event, locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      expect_html_content('Asia/Tokyo')
    end

    it 'displays event time in event timezone' do
      get event_path(event, locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      # Time should be displayed in Tokyo time (JST)
      # The display_event_time helper formats as "Mar 15, 2:00 PM (2 hours)"
      expect_html_content('2:00 PM') # Start time in 12-hour format
    end

    it 'displays timezone offset indicator' do
      get event_path(event, locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      # Should show GMT offset for Tokyo timezone
      expect_html_content('GMT+09:00')
    end

    context 'when viewer timezone differs from event timezone' do
      before do
        person.update!(time_zone: 'America/New_York')
      end

      it 'displays viewer local time conversion' do
        get event_path(event, locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        # Should show conversion: "14:00 JST (00:00 EST Your Time)"
        expect_html_content('Your Time')
      end
    end
  end

  describe 'GET /events (index page)', :as_user do
    let(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
    let(:person) { user.person }

    let!(:tokyo_event) do
      tokyo_tz = ActiveSupport::TimeZone['Asia/Tokyo']
      event = create(:event,
                     name: 'Tokyo Morning Event',
                     timezone: 'Asia/Tokyo',
                     starts_at: tokyo_tz.parse('2026-03-15 09:00:00'),
                     ends_at: tokyo_tz.parse('2026-03-15 11:00:00'),
                     creator: person)
      create(:better_together_event_host, event: event, host: community)
      event
    end

    let!(:london_event) do
      london_tz = ActiveSupport::TimeZone['Europe/London']
      event = create(:event,
                     name: 'London Afternoon Event',
                     timezone: 'Europe/London',
                     starts_at: london_tz.parse('2026-03-15 14:00:00'),
                     ends_at: london_tz.parse('2026-03-15 16:00:00'),
                     creator: person)
      create(:better_together_event_host, event: event, host: community)
      event
    end

    it 'displays timezone for each event' do
      get events_path(locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      expect_html_contents('Asia/Tokyo', 'Europe/London')
    end

    it 'displays time in event timezone for each event' do
      get events_path(locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      # Times are formatted as "Mar 15, 9:00 AM (2 hours)" and "Mar 15, 2:00 PM (2 hours)"
      expect_html_contents('9:00 AM', '2:00 PM')
    end

    it 'shows timezone badges for quick identification' do
      get events_path(locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      # Look for badge/label elements with timezone info
      expect(response.body).to include('badge')
    end
  end

  describe 'Event card partial timezone display', :as_user do
    let(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
    let(:person) { user.person }

    let(:event) do
      sydney_tz = ActiveSupport::TimeZone['Australia/Sydney']
      create(:event,
             name: 'Sydney Workshop',
             timezone: 'Australia/Sydney',
             starts_at: sydney_tz.parse('2026-04-20 10:00:00'),
             ends_at: sydney_tz.parse('2026-04-20 12:00:00'),
             creator: person)
    end

    before do
      create(:better_together_event_host, event: event, host: community)
      get events_path(locale: I18n.default_locale)
    end

    it 'includes timezone badge in event card' do
      expect(response.body).to include('Australia/Sydney')
    end

    it 'displays formatted time with timezone context' do
      # Time is formatted as "Apr 20, 10:00 AM (2 hours)"
      expect_html_content('10:00 AM')
    end
  end
end
