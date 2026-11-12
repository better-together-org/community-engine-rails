# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_refund_requests_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_refund_requests_spec.rb.
RSpec.describe 'Documentation screenshots for billing refund requests', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:buyer_user) { find_or_create_test_user('user@example.test') }
  let(:steward_user) { find_or_create_test_user('manager@example.test', nil, :platform_manager) }
  let!(:order) { place_offline('cash') }
  let!(:refund_request) do
    transition.receive(offline_for(order), by: steward)
    order.reload
    BetterTogether::Billing::RefundRequest.create!(order:, platform_id: order.platform_id, requester: buyer, currency: order.currency,
                                                   reason: 'requested_by_buyer', amount_cents: 2000, details: 'The date no longer suits me.')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_refund_requests', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_page(path, as: :manager)
    as == :buyer ? capybara_login_as_user : capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/#{path}"
  end

  it 'captures the buyer\'s request form, with the refund policy to accept' do
    BetterTogether::Billing::RefundRequest.where(order:).destroy_all
    policy = BetterTogether::Agreement.find_by!(platform: host_platform, identifier: 'refund_policy')
    policy.update!(lifecycle_state: 'active')
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_refund_request_new',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_refund_request_new'),
      callouts: [{ id: 'form', selector: '#billing-refund-request-form', title: 'Ask for a refund',
                   bullets: ['Choose a reason, say how much, and tell the seller what they should know.'] },
                 { id: 'policy', selector: '#billing-refund-policy', title: 'Refund policy',
                   bullets: ['Read the policy in the window, then tick the box to send the request.'] }]
    ) do
      visit_page("orders/#{order.id}/refund_requests/new", as: :buyer)
      expect(page).to have_css('#billing-refund-policy')
      page.execute_script("document.getElementById('billing-refund-policy').scrollIntoView({block: 'center'})")
    end
    policy.update!(lifecycle_state: 'draft')
  end

  it 'captures the request waiting on the buyer\'s order' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_refund_request_on_order',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_refund_request_on_order'),
      callouts: [{ id: 'requests', selector: '#billing-order-refund-requests', title: 'Refund requests',
                   bullets: ['The request, where it stands, and the seller\'s reply once there is one.'] }]
    ) do
      visit_page("orders/#{order.id}", as: :buyer)
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(refund_request)}")
    end
  end

  it 'captures the steward\'s queue' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_refund_requests_queue',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_refund_requests_queue'),
      callouts: [{ id: 'queue', selector: '#billing-refund-requests-table', title: 'Waiting requests',
                   bullets: ['Filter by status, then open a request to decide it.'] }]
    ) do
      visit_page('refund_requests')
      expect(page).to have_css('#billing-refund-requests-table')
    end
  end

  it 'captures the steward\'s decision form' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_refund_request_decide',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_refund_request_decide'),
      callouts: [{ id: 'decision', selector: '#billing-refund-decision-form', title: 'Decide',
                   bullets: ['Approve all, give back part, or decline with a reply the buyer reads.'] }]
    ) do
      visit_page("refund_requests/#{refund_request.id}")
      expect(page).to have_css('#billing-refund-decision-form')
    end
  end
end
