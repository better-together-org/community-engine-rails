# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Events', type: :request do
  include BetterTogether::Engine.routes.url_helpers
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }

  describe 'GET /events' do
    let!(:event) { BetterTogether::Event.create!(name: 'Sample Event') }

    it 'returns http success' do
      get events_path(locale: locale)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /events' do
    let(:user) { create(:better_together_user, :confirmed, :platform_manager) }

    before { login(user) }

    it 'creates an event' do
      expect do
        post events_path(locale: locale), params: { event: { name: 'New Event' } }
      end.to change(BetterTogether::Event, :count).by(1)
      expect(response).to redirect_to(event_path(BetterTogether::Event.last, locale: locale))
    end
  end

  describe 'PATCH /events/:id' do
    let(:user) { create(:better_together_user, :confirmed, :platform_manager) }
    let!(:event) { BetterTogether::Event.create!(name: 'Old Name', creator: user.person) }

    before { login(user) }

    it 'updates the event' do
      patch event_path(event, locale: locale), params: { event: { name: 'Updated Name' } }
      expect(response).to redirect_to(edit_event_path(event, locale: locale))
      expect(event.reload.name).to eq('Updated Name')
    end
  end

  describe 'DELETE /events/:id' do
    let(:user) { create(:better_together_user, :confirmed, :platform_manager) }
    let!(:event) { BetterTogether::Event.create!(name: 'Delete Me', creator: user.person) }

    before { login(user) }

    it 'destroys the event' do
      expect do
        delete event_path(event, locale: locale)
      end.to change(BetterTogether::Event, :count).by(-1)
      expect(response).to redirect_to(events_path(locale: locale))
    end
  end
end
