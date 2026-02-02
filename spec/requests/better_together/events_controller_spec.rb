# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::EventsController', :as_user do
  let(:locale) { I18n.default_locale }

  describe 'GET /events/:id.ics' do
    let(:test_event) do
      BetterTogether::Event.create!(
        name: 'Community Gathering',
        starts_at: 2.days.from_now,
        ends_at: 3.days.from_now,
        identifier: SecureRandom.uuid,
        privacy: 'public'
      )
    end

    context 'with a published event (starts_at present)' do
      before do
        get better_together.ics_event_path(test_event, locale:)
      end

      it 'returns successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct content type' do
        expect(response.media_type).to eq('text/calendar')
      end

      it 'includes calendar start header' do
        expect(response.body).to include('BEGIN:VCALENDAR')
      end

      it 'includes calendar end header' do
        expect(response.body).to include('END:VCALENDAR')
      end

      it 'includes event summary' do
        expect(response.body).to include('SUMMARY:Community Gathering')
      end

      it 'includes unique event identifier' do
        expect(response.body).to include("UID:event-#{test_event.id}@better-together")
      end

      it 'includes event URL' do
        expect(response.body).to include('URL;VALUE=URI:')
      end
    end

    context 'with a draft event (starts_at nil)' do
      let(:draft_event) do
        BetterTogether::Event.create!(
          name: 'Draft Event',
          starts_at: nil,
          ends_at: nil,
          identifier: SecureRandom.uuid,
          privacy: 'public'
        )
      end

      it 'denies access to .ics format' do
        get better_together.ics_event_path(draft_event, locale:)
        expect(response).to have_http_status(:found)
        expect(flash[:error]).to be_present
      end
    end

    context 'with a draft event as creator', :as_platform_manager do
      let(:manager_user) do
        BetterTogether::User.find_by(email: 'manager@example.test') ||
          create(:better_together_user, :confirmed, :platform_manager, email: 'manager@example.test')
      end

      let(:draft_event) do
        BetterTogether::Event.create!(
          name: 'Draft Event by Manager',
          starts_at: nil,
          ends_at: nil,
          identifier: SecureRandom.uuid,
          privacy: 'public',
          creator: manager_user.person
        )
      end

      it 'denies access to .ics format even for creator' do
        get better_together.ics_event_path(draft_event, locale:)
        expect(response).to have_http_status(:found)
        expect(flash[:error]).to be_present
      end
    end
  end

  describe 'GET /events/:id/ics (standalone ics action)' do
    context 'with a published event (starts_at present)' do
      let(:test_event) do
        BetterTogether::Event.create!(
          name: 'Community Gathering',
          starts_at: 2.days.from_now,
          ends_at: 3.days.from_now,
          identifier: SecureRandom.uuid,
          privacy: 'public'
        )
      end

      it 'returns successful response' do
        get better_together.ics_event_path(test_event, locale:)
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/calendar')
      end
    end

    context 'with a draft event (starts_at nil)' do
      let(:draft_event) do
        BetterTogether::Event.create!(
          name: 'Draft Event',
          starts_at: nil,
          ends_at: nil,
          identifier: SecureRandom.uuid,
          privacy: 'public'
        )
      end

      it 'denies access to standalone ics action' do
        get better_together.ics_event_path(draft_event, locale:)
        expect(response).to have_http_status(:found)
        expect(flash[:error]).to be_present
      end
    end
  end

  describe 'GET /events/:id' do
    let(:manager_user) do
      BetterTogether::User.find_by(email: 'manager@example.test') ||
        create(:better_together_user, :confirmed, :platform_manager, email: 'manager@example.test')
    end

    let(:event) do
      BetterTogether::Event.create!(
        name: 'Neighborhood Clean-up',
        starts_at: 1.day.from_now,
        identifier: SecureRandom.uuid,
        privacy: 'public',
        creator: manager_user.person
      )
    end

    context 'as platform manager', :as_platform_manager do
      it 'shows attendees tab to organizers' do # rubocop:todo RSpec/MultipleExpectations
        get better_together.event_path(event, locale:)

        expect(response).to have_http_status(:ok)
        # Look for the attendees tab nav link by id to avoid matching HTML comments
        expect(response.body).to include('id="attendees-tab"')
      end
    end

    context 'as regular user', :as_user do
      it 'does not show attendees tab to non-organizer' do # rubocop:todo RSpec/MultipleExpectations
        get better_together.event_path(event, locale:)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('id="attendees-tab"')
      end
    end
  end

  describe 'RSVP actions' do
    let(:user_email) { 'manager@example.test' }
    let(:password) { 'SecureTest123!@#' }
    let(:event) do
      BetterTogether::Event.create!(name: 'RSVP Test', starts_at: 1.day.from_now, identifier: SecureRandom.uuid)
    end

    it 'requires login' do
      post better_together.rsvp_going_event_path(event, locale:)

      expect(response).to have_http_status(:found)
    end

    it 'prevents RSVP creation without login' do
      post better_together.rsvp_going_event_path(event, locale:)

      expect(BetterTogether::EventAttendance.where(event:).count).to eq(0)
    end

    context 'when logged in as platform manager' do
      it 'creates RSVP as interested' do
        post better_together.rsvp_interested_event_path(event, locale:)
        attendance = BetterTogether::EventAttendance.find_by(event: event)

        expect(attendance&.status).to eq('interested')
      end

      it 'updates RSVP to going' do
        post better_together.rsvp_interested_event_path(event, locale:)
        post better_together.rsvp_going_event_path(event, locale:)
        attendance = BetterTogether::EventAttendance.find_by(event: event)

        expect(attendance.reload.status).to eq('going')
      end

      it 'cancels RSVP' do
        post better_together.rsvp_going_event_path(event, locale:)
        delete better_together.rsvp_cancel_event_path(event, locale:)

        expect(BetterTogether::EventAttendance.where(event: event).count).to eq(0)
      end

      context 'with draft events' do # rubocop:todo RSpec/NestedGroups
        let(:draft_event) do
          BetterTogether::Event.create!(name: 'Draft RSVP Test', identifier: SecureRandom.uuid)
        end

        it 'prevents RSVP for draft events' do # rubocop:todo RSpec/MultipleExpectations
          post better_together.rsvp_interested_event_path(draft_event, locale:)

          expect(response).to redirect_to(draft_event)
          expect(flash[:alert]).to eq('RSVP is not available for this event.')
          expect(BetterTogether::EventAttendance.where(event: draft_event).count).to eq(0)
        end

        it 'prevents going RSVP for draft events' do # rubocop:todo RSpec/MultipleExpectations
          post better_together.rsvp_going_event_path(draft_event, locale:)

          expect(response).to redirect_to(draft_event)
          expect(flash[:alert]).to eq('RSVP is not available for this event.')
          expect(BetterTogether::EventAttendance.where(event: draft_event).count).to eq(0)
        end
      end
    end
  end

  describe 'creating events with different location types' do
    let(:locale) { I18n.default_locale }

    context 'as platform manager', :as_platform_manager do
      # rubocop:todo RSpec/MultipleExpectations
      it 'creates an event with a simple (name) location' do # rubocop:todo RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        params = {
          event: {
            name: 'Simple Location Event',
            starts_at: 1.day.from_now.iso8601,
            identifier: SecureRandom.uuid,
            privacy: 'public',
            location_attributes: {
              name: 'Community Hall'
            }
          },
          locale: locale
        }

        post better_together.events_path(locale: locale), params: params

        expect(response).to have_http_status(:found)
        event = BetterTogether::Event.order(:created_at).last
        expect(event).to be_present
        expect(event.location).to be_present
        expect(event.location.name).to eq('Community Hall')
        expect(event.location.location).to be_nil
      end

      # rubocop:todo RSpec/MultipleExpectations
      it 'creates an event with an Address location' do # rubocop:todo RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        address = create(:better_together_address, privacy: 'public')

        params = {
          event: {
            name: 'Address Location Event',
            starts_at: 1.day.from_now.iso8601,
            identifier: SecureRandom.uuid,
            privacy: 'public',
            location_attributes: {
              location_id: address.id,
              location_type: 'BetterTogether::Address'
            }
          },
          locale: locale
        }

        post better_together.events_path(locale: locale), params: params

        expect(response).to have_http_status(:found)
        event = BetterTogether::Event.order(:created_at).last
        expect(event).to be_present
        expect(event.location).to be_present
        expect(event.location.location_type).to eq('BetterTogether::Address')
        expect(event.location.address).to be_present
        expect(event.location.address.id).to eq(address.id)
      end

      # rubocop:todo RSpec/MultipleExpectations
      it 'creates an event with a Building location' do # rubocop:todo RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        manager_user = BetterTogether::User.find_by(email: 'manager@example.test') ||
                       create(:better_together_user, :confirmed, :platform_manager, email: 'manager@example.test')
        building = create(:better_together_infrastructure_building, creator: manager_user.person, privacy: 'private')

        params = {
          event: {
            name: 'Building Location Event',
            starts_at: 1.day.from_now.iso8601,
            identifier: SecureRandom.uuid,
            privacy: 'public',
            location_attributes: {
              location_id: building.id,
              location_type: 'BetterTogether::Infrastructure::Building'
            }
          },
          locale: locale
        }

        post better_together.events_path(locale: locale), params: params

        expect(response).to have_http_status(:found)
        event = BetterTogether::Event.order(:created_at).last
        expect(event).to be_present
        expect(event.location).to be_present
        expect(event.location.location_type).to eq('BetterTogether::Infrastructure::Building')
        expect(event.location.building).to be_present
        expect(event.location.building.id).to eq(building.id)
      end

      # rubocop:todo RSpec/MultipleExpectations
      it 'creates a draft event with no location assigned' do # rubocop:todo RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        params = {
          event: {
            name: 'Draft Event Without Location',
            identifier: SecureRandom.uuid,
            privacy: 'public'
            # intentionally omit starts_at to keep it a draft and omit location_attributes
          },
          locale: locale
        }

        post better_together.events_path(locale: locale), params: params

        expect(response).to have_http_status(:found)
        event = BetterTogether::Event.order(:created_at).last
        expect(event).to be_present
        expect(event.starts_at).to be_nil
        expect(event).to be_draft
        expect(event.location).to be_nil
      end
    end
  end

  describe 'timezone-aware datetime handling', :as_platform_manager do
    let(:locale) { I18n.default_locale }

    context 'when creating an event with Eastern timezone while user is in Newfoundland timezone' do
      # rubocop:disable RSpec/MultipleExpectations
      it 'interprets datetime values in the event timezone, not user timezone' do
        # Simulate user in Newfoundland time viewing the form
        # User enters "2026-03-15 14:00" in the form with Eastern timezone selected
        # Expected: Event stores 2026-03-15 14:00 EST/EDT (which is 2026-03-15 18:00 UTC in winter, 19:00 in summer)

        # March 15, 2026 is after DST starts (March 8, 2026), so EDT is active (UTC-4)
        # User enters 2:00 PM in form, event timezone is America/New_York
        # Should store as 2026-03-15 18:00 UTC (2 PM EDT = 6 PM UTC)

        params = {
          event: {
            name: 'Timezone Test Event',
            timezone: 'America/New_York',
            starts_at: '2026-03-15T14:00',  # 2:00 PM in local time
            ends_at: '2026-03-15T16:00',    # 4:00 PM in local time
            identifier: SecureRandom.uuid,
            privacy: 'public'
          },
          locale: locale
        }

        post better_together.events_path(locale: locale), params: params

        expect(response).to have_http_status(:found)
        event = BetterTogether::Event.order(:created_at).last

        # Verify event was created
        expect(event).to be_present
        expect(event.timezone).to eq('America/New_York')

        # Verify times are stored correctly in UTC
        # 2:00 PM EDT = 6:00 PM UTC (14:00 + 4 hours for EDT offset)
        expect(event.starts_at.utc.hour).to eq(18)
        expect(event.starts_at.utc.day).to eq(15)
        expect(event.starts_at.utc.month).to eq(3)

        # 4:00 PM EDT = 8:00 PM UTC
        expect(event.ends_at.utc.hour).to eq(20)

        # Verify local times match what user entered
        expect(event.local_starts_at.hour).to eq(14)
        expect(event.local_ends_at.hour).to eq(16)
      end
      # rubocop:enable RSpec/MultipleExpectations
    end

    context 'when updating an event timezone and datetime values' do
      let(:existing_event) do
        create(:better_together_event,
               timezone: 'America/St_Johns', # Newfoundland time
               starts_at: Time.utc(2026, 4, 1, 15, 30),  # 11:00 AM NDT (UTC-2:30 after DST)
               ends_at: Time.utc(2026, 4, 1, 17, 30),    # 1:00 PM NDT
               creator: BetterTogether::User.find_by(email: 'manager@example.test').person)
      end

      # rubocop:disable RSpec/MultipleExpectations
      it 'interprets new datetime values in the new event timezone' do
        # User changes timezone to Eastern and enters new times
        # New times should be interpreted as Eastern, not Newfoundland

        params = {
          event: {
            timezone: 'America/New_York',
            starts_at: '2026-04-01T14:00',  # 2:00 PM in form (should be EDT)
            ends_at: '2026-04-01T16:00'     # 4:00 PM in form (should be EDT)
          },
          locale: locale
        }

        patch better_together.event_path(existing_event, locale: locale), params: params

        expect(response).to have_http_status(:found)
        existing_event.reload

        # Verify timezone changed
        expect(existing_event.timezone).to eq('America/New_York')

        # April 1, 2026 is after DST starts, so EDT is active (UTC-4)
        # 2:00 PM EDT = 6:00 PM UTC
        expect(existing_event.starts_at.utc.hour).to eq(18)
        expect(existing_event.ends_at.utc.hour).to eq(20)

        # Verify local times in new timezone
        expect(existing_event.local_starts_at.hour).to eq(14)
        expect(existing_event.local_ends_at.hour).to eq(16)
        # rubocop:enable RSpec/MultipleExpectations
      end
    end

    context 'when updating only datetime without changing timezone' do
      let(:existing_event) do
        create(:better_together_event,
               timezone: 'America/Los_Angeles',
               starts_at: Time.utc(2026, 5, 15, 19, 0),  # 12:00 PM PDT
               ends_at: Time.utc(2026, 5, 15, 21, 0),    # 2:00 PM PDT
               creator: BetterTogether::User.find_by(email: 'manager@example.test').person)
      end
      # rubocop:disable RSpec/MultipleExpectations

      it 'interprets datetime values in the existing event timezone' do
        params = {
          event: {
            starts_at: '2026-05-15T15:00',  # 3:00 PM in form
            ends_at: '2026-05-15T17:00'     # 5:00 PM in form
          },
          locale: locale
        }

        patch better_together.event_path(existing_event, locale: locale), params: params

        expect(response).to have_http_status(:found)
        existing_event.reload

        # Timezone unchanged
        expect(existing_event.timezone).to eq('America/Los_Angeles')

        # May 15, 2026 has PDT active (UTC-7)
        # 3:00 PM PDT = 10:00 PM UTC
        expect(existing_event.starts_at.utc.hour).to eq(22)
        # 5:00 PM PDT = 12:00 AM UTC next day
        expect(existing_event.ends_at.utc.hour).to eq(0)
        expect(existing_event.ends_at.utc.day).to eq(16)

        # Verify local times
        expect(existing_event.local_starts_at.hour).to eq(15)
        # rubocop:enable RSpec/MultipleExpectations
        expect(existing_event.local_ends_at.hour).to eq(17)
      end
    end
  end
end
