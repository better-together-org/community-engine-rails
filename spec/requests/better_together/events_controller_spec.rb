# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::EventsController' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let!(:user) { create(:user, :confirmed) }

  before do
    configure_host_platform
    logout(:user)
    login_as(user, scope: :user)
  end

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
      expect(response.body).to include('URL:')
    end
  end

  describe 'RSVP actions' do
    let(:user_email) { 'manager@example.test' }
    let(:password) { 'password12345' }
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

    context 'when logged in' do
      before do
        logout(:user)
        login(user_email, password)
      end

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
    end
  end
end
