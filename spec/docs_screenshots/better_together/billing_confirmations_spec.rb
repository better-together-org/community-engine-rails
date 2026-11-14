# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_confirmations_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_confirmations_spec.rb. The confirmation itself is a
# native browser dialog, which a page screenshot cannot show; the callouts say what it asks.
RSpec.describe 'Documentation screenshots for steward confirmations', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_confirmations', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  it 'captures the payments queue, where marking received asks first' do
    transition.claim(offline, reference: 'sent')
    button = "#billing-offline-confirm-btn-#{order.id}"

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_confirm_queue',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_confirm_queue'),
      callouts: [{ id: 'mark-received', selector: button, title: 'Mark received asks first',
                   avoid_container_selector: 'main',
                   bullets: ['Names the order, the buyer and the amount, so a stray click does not settle an order.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/offline_payments"
      scroll_to(find(button), align: :center)
      expect(page).to have_css(button)
    end
  end

  it 'captures the refund form on a sale, where the typed amount is repeated back' do
    transition.receive(offline, by: steward)
    form = "#billing-sale-refund-form-#{offline.id}"

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_confirm_refund',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_confirm_refund'),
      callouts: [{ id: 'record-refund', selector: "##{ActionView::RecordIdentifier.dom_id(offline.payment, :refund)}",
                   title: 'Record refund asks first',
                   avoid_container_selector: 'main',
                   bullets: ['The question repeats the amount typed, or the full amount when it is left blank.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/sales/#{order.id}"
      fill_in "refund_amount_#{offline.id}", with: '12.50'
      scroll_to(find(form), align: :bottom)
      expect(page).to have_css(form)
    end
  end

  it 'captures the store credit grant form' do
    create(:better_together_person_platform_membership, joinable: host_platform, member: buyer)
    form = '#billing-credit-grant-form'

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_confirm_grant',
      device: :both,
      metadata: screenshot_metadata(flow: 'billing_confirm_grant'),
      callouts: [{ id: 'give-credit', selector: '#billing-credit-grant-btn', title: 'Give credit asks first',
                   avoid_container_selector: 'main',
                   bullets: ['Names the person and the amount before any credit is created.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/credit_accounts?person_id=#{buyer.id}"
      fill_in 'billing-credit-grant-amount', with: '20'
      scroll_to(find(form), align: :center)
      expect(page).to have_css(form)
    end
  end
end
