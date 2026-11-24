# frozen_string_literal: true

require 'rails_helper'

# Acceptance journey in a real browser: a buyer finds a plan in the catalog, reads and ticks the agreements, pays by
# cash, a steward confirms the payment, and the buyer then has the subscription and what it includes.
RSpec.describe 'Billing buyer journey', :js, :no_auth, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::BillingAddressHelpers
  include ActiveJob::TestHelper

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let!(:plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'month',
                                                     name: 'Journey supporter', currency: 'USD', amount_cents: 1000, listed: true)
  end
  let!(:buyer_address) { create_billing_address_for(find_or_create_test_user('user@example.test').person) }

  before do
    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
  end

  after { Current.platform = nil }

  def switch_user
    Capybara.reset_session!
    page.driver.browser.manage.delete_all_cookies
    @capybara_signed_in_user_email = nil
  end

  def agreement_identifiers
    page.all('#billing-agreement-review .agreement-modal-link').map { |link| link[:id].delete_prefix('billing-agreement-view-') }
  end

  def read_and_tick_all_agreements # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    agreement_identifiers.each do |identifier|
      find("#billing-agreement-view-#{identifier}").click
      expect(page).to have_css('#agreementModal.show #agreement_modal_frame', wait: 10)
      page.execute_script(<<~JS)
        const body = document.getElementById('agreement_modal_frame').closest('.modal-body');
        body.scrollTop = body.scrollHeight;
        body.dispatchEvent(new Event('scroll', { bubbles: true }));
      JS
      box = "#billing-agreement-accept-#{identifier}"
      expect(page).to have_css("#{box}[data-better-together-agreement-enabled='true']", visible: :all, wait: 10)
      sleep 0.5
      find('#agreementModal .modal-footer [data-bs-dismiss="modal"]').click
      expect(page).to have_no_css('#agreementModal.show', wait: 10)
      find(box).click
    end
  end

  it 'takes a buyer from the catalog to a confirmed, active subscription', :aggregate_failures do
    capybara_login_as_user
    visit "/#{locale}/billing/catalog"
    expect(page).to have_content('Journey supporter')
    expect(page).to be_axe_clean.within('main').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa).skipping('region')

    click_link 'Subscribe Journey supporter'
    expect(page).to have_current_path(%r{/billing/checkout/new}, wait: 10)
    find('#billing-checkout-method-cash').click
    click_button 'billing-checkout-continue-btn'
    expect(page).to have_css('#billing-checkout-address-select', visible: :all, wait: 10)
    page.execute_script("document.getElementById('billing-checkout-address-select').value = '#{buyer_address.id}'")
    read_and_tick_all_agreements
    click_button 'billing-checkout-place-btn'
    expect(page).to have_current_path(%r{/billing/orders/}, wait: 15)
    order = BetterTogether::Billing::Order.order(:created_at).last
    expect(order.status).not_to eq('paid')

    switch_user
    capybara_login_as_platform_manager
    visit "/#{locale}/billing/sales/#{order.id}"
    receive = page.find("form[id^='billing-offline-receive-form-'] [type=submit]")
    perform_enqueued_jobs do
      accept_confirm { receive.click }
      expect(page).to have_css('.alert', wait: 15)
      sleep 1
    end

    expect(order.reload.status).to eq('paid')
    switch_user
    capybara_login_as_user
    visit "/#{locale}/billing/subscriptions"
    expect(page).to have_content('Journey supporter')
    expect(page).to have_content('Active')
    visit "/#{locale}/billing"
    expect(page).to have_content('Journey supporter')
  end
end
