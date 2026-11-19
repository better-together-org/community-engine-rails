# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::EventsController do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("events-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("events-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:other_platform) { create(:better_together_platform) }
  let!(:failed) { create(:better_together_billing_event, processing_status: 'failed', attempt_count: 2, last_attempted_at: 1.hour.ago) }
  let!(:dead) do
    create(:better_together_billing_event, processing_status: 'dead_lettered', dead_lettered_at: 1.hour.ago,
                                           dead_letter_reason: 'retries_exhausted', last_attempted_at: 2.hours.ago,
                                           payload: { 'id' => 'evt_x', 'type' => 'fake.invoice.paid', 'card' => 'do-not-show' })
  end
  let!(:done) { create(:better_together_billing_event, processing_status: 'processed') }

  before { BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new }) }

  def events_path(**params) = better_together.billing_events_path(locale:, **params)
  def event_path(event) = better_together.billing_event_path(event, locale:)
  def replay_path(event) = better_together.replay_billing_event_path(event, locale:)

  describe 'who may reach it' do
    it 'sends a visitor to sign in' do
      get events_path

      expect(response).to have_http_status(:found)
    end

    it 'turns a signed-in non-steward away' do
      sign_in member

      get events_path
      expect(response.body).not_to include('billing-events-table')

      post replay_path(dead)
      expect(dead.reload.processing_status).to eq('dead_lettered')
    end

    it 'is a 404 while billing is not switched on' do
      sign_in steward
      allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

      get events_path

      expect(response).to have_http_status(:not_found)
    end

    it 'does not show events of another platform' do
      sign_in steward
      foreign = create(:better_together_billing_event, platform: other_platform)

      get event_path(foreign)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'index' do
    before { sign_in steward }

    it 'lists the events that need attention by default, with the alerts, and no payload' do
      get events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-events-alerts', ActionView::RecordIdentifier.dom_id(failed), ActionView::RecordIdentifier.dom_id(dead))
      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(done), 'do-not-show')
    end

    it 'filters by state' do
      get events_path(state: 'dead_lettered')

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(dead))
      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(failed))
    end

    it 'falls back to the default for an unknown state' do
      get events_path(state: 'bogus')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(failed))
    end

    it 'says so when a state has no events' do
      get events_path(state: 'replayed')

      expect(response.body).to include('billing-events-empty')
    end

    it 'marks the chosen filter as the current page' do
      get events_path(state: 'failed')

      expect(response.parsed_body.at_css('#billing-events-filter-failed')['aria-current']).to eq('page')
    end
  end

  describe 'show' do
    before { sign_in steward }

    it 'shows the history and a retry button, never the payload' do
      get event_path(dead)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-event-replay-btn', 'It failed too many times.')
      expect(response.body).not_to include('do-not-show')
    end

    it 'explains why an event whose payload was removed cannot be retried' do
      dead.update!(payload_redacted_at: Time.current)

      get event_path(dead)

      expect(response.body).to include('billing-event-replay-unavailable')
      expect(response.body).not_to include('billing-event-replay-btn')
    end

    it 'offers no retry for an event that went through' do
      get event_path(done)

      expect(response.body).to include('billing-event-replay-not-needed')
    end
  end

  describe 'replay' do
    before { sign_in steward }

    it 'queues the event again and records who asked' do
      expect { post replay_path(dead) }.to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob).with(dead.id)

      expect(response).to redirect_to(event_path(dead))
      expect(dead.reload).to have_attributes(processing_status: 'replayed', last_replay_requested_by_id: steward.person.id)
    end

    it 'does nothing the second time' do
      post replay_path(dead)

      expect { post replay_path(dead) }.not_to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)
      expect(dead.reload.replay_count).to eq(1)
      expect(flash[:alert]).to be_present
    end

    it 'refuses an event that is not a problem' do
      expect { post replay_path(done) }.not_to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)
      expect(done.reload.processing_status).to eq('processed')
    end

    it 'says why when the message was removed' do
      dead.update!(payload_redacted_at: Time.current)

      post replay_path(dead)

      expect(flash[:alert]).to eq(I18n.t('better_together.billing.events.refused.payload_unavailable'))
    end
  end
end
