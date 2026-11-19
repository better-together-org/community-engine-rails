# frozen_string_literal: true

require 'rails_helper'

# "Billing notifications": which billing notices are also emailed.
RSpec.describe BetterTogether::Billing::NotificationPreferencesController do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("prefs-member-#{SecureRandom.hex(4)}@example.test", password) }

  def prefs_path = better_together.billing_notification_preferences_path(locale:)

  it 'sends a visitor to sign in' do
    get prefs_path

    expect(response).to have_http_status(:found)
  end

  context 'when signed in' do
    before { sign_in member }

    it 'shows the choice and the notices that are always sent' do
      get prefs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-notification-preferences-form', 'billing-notify-email', 'billing-notification-always',
                                       'billing-notification-always-payment-failed')
    end

    it 'turns billing emails off and back on' do
      patch prefs_path, params: { notify_billing_by_email: '0' }
      expect(member.person.reload.notification_preferences['notify_billing_by_email']).to be(false)

      patch prefs_path, params: { notify_billing_by_email: '1' }
      expect(member.person.reload.notification_preferences['notify_billing_by_email']).to be(true)
    end
  end
end
