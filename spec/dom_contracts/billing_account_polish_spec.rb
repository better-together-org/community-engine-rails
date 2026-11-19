# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the account polish screens (billing addresses, notification preferences, hub settings).
# Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing account polish DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("polish-#{SecureRandom.hex(4)}@example.test", password) }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  before { sign_in member }

  it 'exposes the hub settings links' do
    get "/#{locale}/billing"

    expect_ids('billing-hub-settings', 'billing-hub-addresses-link', 'billing-hub-notifications-link')
  end

  it 'exposes the billing addresses page' do
    get "/#{locale}/billing/billing_addresses"

    expect_ids('billing-addresses-page', 'billing-addresses-list', 'billing-addresses-new')
  end

  it 'exposes the notification preferences page' do
    get "/#{locale}/billing/notification_preferences"

    expect_ids('billing-notification-preferences-page', 'billing-notification-preferences-form', 'billing-notify-email',
               'billing-notification-always', 'billing-notification-always-payment-failed')
  end
end
