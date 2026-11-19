# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the payment events screens: asserts the stable identifiers that
# documentation screenshots (spec/docs_screenshots/better_together/billing_events_spec.rb)
# and downstream tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing events DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let!(:dead) do
    create(:better_together_billing_event, processing_status: 'dead_lettered', dead_lettered_at: 1.hour.ago,
                                           dead_letter_reason: 'retries_exhausted', attempt_count: 5)
  end

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  it 'exposes the index identifiers, the filters and one row with a view link per event' do
    get "/#{locale}/billing/events"

    expect(response).to have_http_status(:ok)
    expect_ids('billing-events-page', 'billing-events-alerts', 'billing-events-alert-dead-lettered', 'billing-events-filter',
               'billing-events-table', ActionView::RecordIdentifier.dom_id(dead), "billing-event-view-#{dead.id}",
               ActionView::RecordIdentifier.dom_id(dead, :status_badge), 'billing-events-pagination')
    BetterTogether::Billing::EventsController::STATES.each { |state| expect_ids("billing-events-filter-#{state}") }
    expect(response.body).to include('billing-event-status-badge')
  end

  it 'exposes the empty state identifier' do
    get "/#{locale}/billing/events?state=replayed"

    expect_ids('billing-events-page', 'billing-events-empty')
  end

  it 'exposes the clear alerts identifier when nothing needs attention' do
    dead.update!(processing_status: 'processed')

    get "/#{locale}/billing/events"

    expect_ids('billing-events-alerts-clear')
  end

  it 'exposes the detail and retry identifiers' do
    get "/#{locale}/billing/events/#{dead.id}"

    expect_ids('billing-event-page', 'billing-event-back-link', 'billing-event-details', 'billing-event-replay',
               'billing-event-replay-form', 'billing-event-replay-btn')
  end
end
