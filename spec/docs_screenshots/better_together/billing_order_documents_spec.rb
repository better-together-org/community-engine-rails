# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NoExpectationExample
# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_order_documents_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_order_documents_spec.rb.
RSpec.describe 'Documentation screenshots for the order invoice and receipt downloads', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:metadata) do
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_documents', source_spec: self.class.metadata[:file_path] }
  end
  let(:manager) { BetterTogether::User.find_by!(email: 'manager@example.test').person }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  it 'captures the order page with the stored invoice and receipt' do
    order = place_order(buyer: manager)
    BetterTogether::Billing::Orders::GenerateDocument.call(order)
    create(:better_together_billing_payment, order:, amount_cents: order.total_cents, status: 'succeeded', currency: order.currency,
                                             paid_at: Time.current)
    BetterTogether::Billing::Orders::Settle.call(order)
    BetterTogether::Billing::Orders::GenerateDocument.call(order.reload)
    target = "##{ActionView::RecordIdentifier.dom_id(order, :documents)}"

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_order_documents', device: :both, metadata: metadata.merge(flow: 'billing_order_documents'),
                                 callouts: [{ id: 'billing_order_documents', selector: target, title: 'Invoice and receipt',
                                              avoid_container_selector: 'main',
                                              bullets: ['Each stored PDF downloads from its own button.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/orders/#{order.id}"
      scroll_to(find(target), align: :center)
      expect(page).to have_css("#{target} .billing-order-receipt-download")
    end
  end
end
# rubocop:enable RSpec/NoExpectationExample
