# frozen_string_literal: true

require 'rails_helper'

# A subscription renews: the buyer is sent a renewal invoice, the steward records the payment, the period is paid.
RSpec.describe 'Billing renewal', :js, :no_auth, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers
  include ActiveJob::TestHelper

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let!(:buyer_user) { find_or_create_test_user('user@example.test') }
  let(:buyer) { buyer_user.person }
  let!(:term) { start_subscription }
  let!(:renewal) { generate_renewal(term, at: Time.utc(2027, 2, 20)) }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa] }

  before { Current.platform = host_platform }

  after { Current.platform = nil }

  def switch_user
    Capybara.reset_session!
    page.driver.browser.manage.delete_all_cookies
    @capybara_signed_in_user_email = nil
  end

  it 'shows the buyer the renewal invoice, and the period is paid once the steward records the money', :aggregate_failures do
    capybara_login_as_user
    visit "/#{locale}/billing/subscriptions/#{term.id}"

    within("##{ActionView::RecordIdentifier.dom_id(renewal)}") do
      expect(page).to have_link(I18n.t('better_together.billing.subscriptions.invoice', number: renewal.order.number))
    end
    expect(page).to be_axe_clean.within('main').according_to(*wcag).skipping('region')
    click_link I18n.t('better_together.billing.subscriptions.invoice', number: renewal.order.number)
    expect(page).to have_current_path(%r{/billing/orders/#{renewal.order.id}}, wait: 10)

    switch_user
    capybara_login_as_platform_manager
    visit "/#{locale}/billing/sales/#{renewal.order.id}"
    receive = page.find("form[id^='billing-offline-receive-form-'] [type=submit]")
    perform_enqueued_jobs do
      accept_confirm { receive.click }
      expect(page).to have_css('.alert', wait: 15)
      sleep 1
    end

    expect(renewal.order.reload.status).to eq('paid')
    expect(renewal.reload.status).to eq('paid')
  end
end
