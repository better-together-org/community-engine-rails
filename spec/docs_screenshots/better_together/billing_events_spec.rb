# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_events_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_events_spec.rb.
RSpec.describe 'Documentation screenshots for payment events', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:host_platform) { configure_host_platform }
  let!(:dead_event) do
    create(:better_together_billing_event, platform: host_platform, processing_status: 'dead_lettered', dead_lettered_at: 2.hours.ago,
                                           dead_letter_reason: 'retries_exhausted', attempt_count: 5, last_attempted_at: 3.hours.ago,
                                           event_type: 'fake.invoice.paid')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })
    create(:better_together_billing_event, platform: host_platform, processing_status: 'failed', attempt_count: 2,
                                           last_attempted_at: 20.minutes.ago, event_type: 'fake.invoice.payment_failed')
    create(:better_together_billing_event, platform: host_platform, processing_status: 'failed', attempt_count: 4,
                                           last_attempted_at: 7.hours.ago, event_type: 'fake.charge.refunded')
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_events', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the list of events that need attention, with the alerts' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_events_index',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_events_index'),
      callouts: [{ id: 'table', selector: '#billing-events-table', title: 'The events',
                   avoid_container_selector: 'main',
                   bullets: ['State, attempts and why it stopped. The message itself is never shown.'] }],
      narrative: {
        title: 'Payment events',
        audience: %w[platform_organizer],
        journey_step: 'As a host platform operator, I see which payment processor events did not go through.',
        callouts: [{ id: 'alerts', title: 'Alerts', description: 'Events given up on, events that keep failing, and old problems.' },
                   { id: 'table', title: 'Events', description: 'Each row is one message from the payment processor.' },
                   { id: 'filter', title: 'Filter',
                     description: 'Show failed, dead-lettered, waiting or retried events.' }],
        accessibility_notes: 'The table has a caption and column headers; state is text as well as colour; the filter marks the current choice.'
      }
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/events"
      expect(page).to have_css('#billing-events-table')
    end
  end

  it 'captures one event with the retry button' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_events_show',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_events_show'),
      callouts: [{ id: 'retry', selector: '#billing-event-replay-btn', title: 'Retry',
                   avoid_container_selector: 'main',
                   bullets: ['Asks for confirmation, then runs the event again. Safe to do twice.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/events/#{dead_event.id}"
      expect(page).to have_css('#billing-event-replay-btn')
      scroll_to(find('#billing-event-replay'), align: :center)
    end
  end
end
