# frozen_string_literal: true

require 'rails_helper'

# The pages of a series and its sessions: the series lists its dates as cards, each session says which series it is
# part of (naming it only when the names differ), and cancelling or deleting a series asks about its sessions.
RSpec.describe 'Event series pages' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:series) do
    create(:better_together_event, series: true, starts_at: nil, ends_at: nil, privacy: 'public', name: 'Tribute Run')
  end
  let(:session) do
    create(:better_together_event, starts_at: 3.days.from_now, ends_at: 3.days.from_now + 2.hours,
                                   privacy: 'public', name: 'Tribute Night', session_of: series.identifier)
  end

  before do
    configure_host_platform
    session
  end

  describe 'the series page' do
    before { get "/#{locale}/events/#{series.slug}" }

    it 'lists the sessions as cards linking to their own pages', :aggregate_failures do
      expect(response.body).to include("id=\"sessions_event_#{series.id}\"", "events/#{session.slug}")
    end

    it 'offers no calendar, RSVP or tickets for the series itself', :aggregate_failures do
      expect(response.body).not_to include('Add to calendar', 'event_rsvp')
      expect(response.body).not_to include(ics_event_path(series, locale:))
    end
  end

  describe 'a session page' do
    it 'names the series and the other dates when the names differ', :aggregate_failures do
      other = create(:better_together_event, starts_at: 5.days.from_now, ends_at: 5.days.from_now + 1.hour,
                                             privacy: 'public', name: 'Tribute Matinee', session_of: series.identifier)
      get "/#{locale}/events/#{session.slug}"

      expect(response.body).to include('Part of Tribute Run', "events/#{other.slug}")
    end

    it 'says how many dates the series has when the names match', :aggregate_failures do
      session.update!(name: series.name)
      get "/#{locale}/events/#{session.slug}"

      expect(response.body).to include('Part of a series of 1 date')
      expect(response.body).not_to include('Part of Tribute Run')
    end
  end

  describe 'the events list' do
    it 'shows the series as a mention on its sessions', :aggregate_failures do
      get "/#{locale}/events"

      expect(response.body).to include("id=\"series_mention_event_#{session.id}\"", 'Part of Tribute Run')
    end
  end

  describe 'cancelling or deleting as a manager' do
    before { login('manager@example.test', 'SecureTest123!@#') }

    it 'shows the confirmation panel with no choice preselected', :aggregate_failures do
      get "/#{locale}/events/#{series.slug}"

      expect(response.body).to include("id=\"disposition_event_#{series.id}\"", 'session_disposition')
      expect(response.body).not_to match(/session_disposition[^>]*checked/)
    end

    it 'refuses to cancel without a choice', :aggregate_failures do
      patch "/#{locale}/events/#{series.slug}", params: { series_action: 'cancel' }

      expect(series.reload).not_to be_status_cancelled
      expect(response).to redirect_to("/#{locale}/events/#{series.slug}")
    end

    it 'cancels the series and its upcoming sessions when asked', :aggregate_failures do
      patch "/#{locale}/events/#{series.slug}", params: { series_action: 'cancel', session_disposition: 'cancel' }

      expect(series.reload).to be_status_cancelled
      expect(session.reload).to be_status_cancelled
    end

    it 'deletes only the series when the sessions are promoted', :aggregate_failures do
      delete "/#{locale}/events/#{series.slug}", params: { session_disposition: 'promote' }

      expect(BetterTogether::Event.exists?(series.id)).to be(false)
      expect(session.reload.session?).to be(false)
    end

    it 'refuses to delete without a choice' do
      delete "/#{locale}/events/#{series.slug}"

      expect(BetterTogether::Event.exists?(series.id)).to be(true)
    end
  end
end
