# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PeopleController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }

  describe 'GET /:locale/.../host/p/:id' do
    let!(:person) { create(:better_together_person) }

    it 'renders show' do
      get better_together.person_path(locale:, id: person.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'renders edit' do
      get better_together.edit_person_path(locale:, id: person.slug)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /:locale/.../host/p/:id (show) - calendar tab' do
    let!(:person) { platform_manager.person }
    let!(:community) { create(:better_together_community, creator: person) }

    let!(:draft_event) do
      create(:better_together_event,
             :draft,
             name: 'Draft Event',
             creator: person).tap do |event|
        create(:better_together_event_host, event: event, host: community)
      end
    end

    let!(:upcoming_event) do
      create(:better_together_event,
             name: 'Upcoming Event',
             starts_at: 2.days.from_now,
             ends_at: 2.days.from_now + 1.hour,
             creator: person).tap do |event|
        create(:better_together_event_host, event: event, host: community)
      end
    end

    let!(:ongoing_event) do
      create(:better_together_event,
             name: 'Ongoing Event',
             starts_at: 15.minutes.ago,
             ends_at: 15.minutes.from_now,
             duration_minutes: 30,
             creator: person).tap do |event|
        create(:better_together_event_host, event: event, host: community)
      end
    end

    let!(:past_event) do
      create(:better_together_event,
             name: 'Past Event',
             starts_at: 2.days.ago,
             ends_at: 2.days.ago + 1.hour,
             creator: person).tap do |event|
        create(:better_together_event_host, event: event, host: community)
      end
    end

    it 'categorizes events correctly' do
      get better_together.person_path(locale:, id: person.slug)
      expect(response).to have_http_status(:ok)

      expect(assigns(:draft_events)).to include(draft_event)
      expect(assigns(:upcoming_events)).to include(upcoming_event)
      expect(assigns(:ongoing_events)).to include(ongoing_event)
      expect(assigns(:past_events)).to include(past_event)
    end

    it 'displays ongoing events section with translated header' do
      get better_together.person_path(locale:, id: person.slug)
      expect(response.body).to include('Ongoing Event')
      expect(response.body).to include(I18n.t('better_together.people.calendar.ongoing_events'))
    end

    it 'displays in_progress badge for ongoing events' do
      get better_together.person_path(locale:, id: person.slug)
      expect(response.body).to include(I18n.t('better_together.people.calendar.in_progress'))
    end

    it 'uses recent_events translation for past events section' do
      get better_together.person_path(locale:, id: person.slug)
      expect(response.body).to include(I18n.t('better_together.people.calendar.recent_events'))
      expect(response.body).not_to include('recent_past_events')
    end
  end

  describe 'PATCH /:locale/.../host/p/:id' do
    let!(:person) { create(:better_together_person) }

    # rubocop:todo RSpec/MultipleExpectations
    it 'updates name and redirects' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      patch better_together.person_path(locale:, id: person.slug), params: {
        person: { name: 'Updated Name' }
      }
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end
