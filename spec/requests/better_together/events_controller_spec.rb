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
end
