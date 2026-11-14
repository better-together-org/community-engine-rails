# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_account_polish_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_account_polish_spec.rb and the orders and subscriptions contracts.
RSpec.describe 'Documentation screenshots for billing account polish', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let!(:term) { start_subscription }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'buyer', feature_set: 'billing_account_polish', flow:, source_spec: self.class.metadata[:file_path] }
  end

  def scroll_to(id) = page.execute_script("document.getElementById('#{id}').scrollIntoView({block: 'center'})")

  def capture(name, path, selector:, title:, bullet:)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, metadata: screenshot_metadata(flow: name),
            callouts: [{ id: 'target', selector:, title:, bullets: [bullet] }]
    ) do
      capybara_sign_in_user(buyer_user.email, password)
      visit "/#{I18n.default_locale}/billing/#{path}"
      expect(page).to have_css(selector)
      scroll_to(selector.delete('#'))
    end
  end

  # The expectations are inside the capture block (see #capture).
  # rubocop:disable RSpec/NoExpectationExample
  it 'captures the order filters' do
    capture('billing_orders_filters', 'orders?status=paid', selector: '#billing-orders-filters', title: 'Find an order',
                                                            bullet: 'Narrow the list by status or year.')
  end

  it 'captures the change of payment method on a subscription' do
    capture('billing_subscription_method_change', "subscriptions/#{term.id}", selector: '#subscription-method-change',
                                                                              title: 'Change how you pay',
                                                                              bullet: 'Pick another method for the next renewal.')
  end

  it 'captures the billing addresses page' do
    capture('billing_addresses', 'billing_addresses', selector: '#billing-addresses-list', title: 'Billing addresses',
                                                      bullet: 'Keep the addresses used on invoices and choose a default.')
  end

  it 'captures the notification preferences' do
    capture('billing_notification_preferences', 'notification_preferences', selector: '#billing-notification-preferences-form',
                                                                            title: 'Billing emails',
                                                                            bullet: 'Choose whether billing notices are also emailed.')
  end
  # rubocop:enable RSpec/NoExpectationExample
end
