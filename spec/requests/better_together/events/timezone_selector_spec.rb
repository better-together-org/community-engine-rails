# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event Timezone Selector' do
  # Test setup uses automatic configuration - host platform and user authentication
  # are handled by spec/support/automatic_test_configuration.rb
  # User created with email: 'user@example.test', password: 'SecureTest123!@#'

  let(:platform) { BetterTogether::Platform.host.first }
  let(:community) { platform.community }
  let(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
  let(:person) { user.person }

  before do
    # Update platform timezone for testing
    platform.update!(time_zone: 'America/Toronto')
  end

  describe 'GET /events/new', :as_platform_manager do
    it 'displays timezone selector in the form' do
      get new_event_path(locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      expect(response_text).to include('timezone')
    end

    context 'when user has timezone preference' do
      before do
        # Get platform manager's person
        manager_user = BetterTogether::User.find_by(email: 'manager@example.test')
        manager_user.person.update!(time_zone: 'America/Los_Angeles')
      end

      it 'defaults timezone selector to user preference' do
        get new_event_path(locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response_text).to include('Los_Angeles')
      end
    end

    context 'when user has no timezone preference' do
      before do
        manager_user = BetterTogether::User.find_by(email: 'manager@example.test')
        manager_user.person.update!(time_zone: nil)
      end

      it 'defaults timezone selector to platform timezone' do
        get new_event_path(locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response_text).to include('Toronto')
      end
    end
  end

  describe 'POST /events', :as_platform_manager do
    let(:manager_user) { BetterTogether::User.find_by(email: 'manager@example.test') }
    let(:manager_person) { manager_user.person }

    let(:event_params) do
      {
        event: {
          name: 'TDD Event with Timezone',
          description: 'Testing timezone handling',
          identifier: 'tdd-event-timezone',
          timezone: 'America/New_York',
          starts_at: 1.day.from_now,
          ends_at: 1.day.from_now + 2.hours,
          duration_minutes: 120,
          registration_url: 'https://example.com/register',
          privacy: 'public',
          creator_id: manager_person.id,
          event_hosts_attributes: {
            '0' => {
              host_id: community.id,
              host_type: 'BetterTogether::Community'
            }
          }
        }
      }
    end

    it 'creates event with specified timezone' do
      expect do
        post events_path(locale: I18n.default_locale), params: event_params
      end.to change(BetterTogether::Event, :count).by(1)

      event = BetterTogether::Event.last
      expect(event.timezone).to eq('America/New_York')
    end

    it 'validates timezone is valid IANA identifier' do
      event_params[:event][:timezone] = 'Invalid/Timezone'

      post events_path(locale: I18n.default_locale), params: event_params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response_text).to include('timezone')
    end

    context 'when timezone is not provided' do
      before do
        event_params[:event].delete(:timezone)
      end

      it 'defaults to UTC when timezone not provided' do
        expect do
          post events_path(locale: I18n.default_locale), params: event_params
        end.to change(BetterTogether::Event, :count).by(1)

        event = BetterTogether::Event.last
        expect(event.timezone).to eq('UTC') # Database default
      end
    end
  end

  describe 'GET /events/:id/edit', :as_platform_manager do
    let(:manager_user) { BetterTogether::User.find_by(email: 'manager@example.test') }
    let(:manager_person) { manager_user.person }

    let(:event) do
      create(:event,
             timezone: 'Europe/London',
             creator: manager_person,
             starts_at: Time.current,
             ends_at: 2.hours.from_now)
    end

    before do
      # Associate event with community
      create(:better_together_event_host, event: event, host: community)
    end

    it 'displays current timezone in selector' do
      get edit_event_path(event, locale: I18n.default_locale)

      expect(response).to have_http_status(:success)
      expect(response_text).to include('London')
    end
  end

  describe 'PATCH /events/:id', :as_platform_manager do
    let(:manager_user) { BetterTogether::User.find_by(email: 'manager@example.test') }
    let(:manager_person) { manager_user.person }

    let(:event) do
      create(:event,
             timezone: 'America/Toronto',
             creator: manager_person,
             starts_at: Time.current,
             ends_at: 2.hours.from_now)
    end

    before do
      create(:better_together_event_host, event: event, host: community)
    end

    it 'updates event timezone' do
      patch event_path(event, locale: I18n.default_locale),
            params: {
              event: {
                timezone: 'Asia/Tokyo',
                starts_at: event.starts_at,
                ends_at: event.ends_at
              }
            }

      event.reload
      expect(event.timezone).to eq('Asia/Tokyo')
    end

    it 'prevents setting invalid timezone' do
      patch event_path(event, locale: I18n.default_locale),
            params: {
              event: {
                timezone: 'Not/A/Timezone',
                starts_at: event.starts_at,
                ends_at: event.ends_at
              }
            }

      expect(response).to have_http_status(:unprocessable_content)
      event.reload
      expect(event.timezone).to eq('America/Toronto') # unchanged
    end
  end
end
