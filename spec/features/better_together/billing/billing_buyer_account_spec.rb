# frozen_string_literal: true

require 'rails_helper'

# Browser acceptance for what a buyer does after the first purchase, and for the visitor before it: the public
# catalog, a new billing address, cancelling and resuming, changing plan, and asking for a refund.
RSpec.describe 'Billing buyer account', :js, :no_auth, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::BillingAddressHelpers
  include ActiveJob::TestHelper

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let!(:buyer_user) { find_or_create_test_user('user@example.test') }
  let(:buyer) { buyer_user.person }
  let(:wcag) { %i[wcag2a wcag2aa wcag21a wcag21aa] }

  before { Current.platform = host_platform }

  after { Current.platform = nil }

  def accept_prompt_and_click(selector)
    accept_confirm { find(selector).click }
  end

  def pick_geography(level, name)
    select_id = "billing_address_#{level}_select"
    content = "div.ss-content[data-id='#{find("##{select_id}", visible: :all)['data-id']}']"
    find("##{select_id}", visible: :all).find(:xpath, '..').find('.ss-main').click
    within(content, visible: :all) { find('.ss-search input').set(name) }
    find("#{content} .ss-option", text: /#{Regexp.escape(name)}/i, match: :first, wait: 10).click
  end

  # The picker sets its hidden id field after the click, so wait for it.
  def expect_hidden_value_set(selector)
    page.document.synchronize(10) { raise Capybara::ElementNotFound, selector if find(selector, visible: :all).value.blank? }
  end

  def read_and_tick_refund_policy # rubocop:disable Metrics/AbcSize
    return unless page.has_css?('#billing-refund-policy-accept', visible: :all, wait: 2)

    find('#billing-refund-policy-view').click
    expect(page).to have_css('#agreementModal.show #agreement_modal_frame', wait: 10)
    page.execute_script(<<~JS)
      const body = document.getElementById('agreement_modal_frame').closest('.modal-body');
      body.scrollTop = body.scrollHeight;
      body.dispatchEvent(new Event('scroll', { bubbles: true }));
    JS
    expect(page).to have_css("#billing-refund-policy-accept[data-better-together-agreement-enabled='true']", visible: :all, wait: 10)
    sleep 0.5
    find('#agreementModal .modal-footer [data-bs-dismiss="modal"]').click
    expect(page).to have_no_css('#agreementModal.show', wait: 10)
    find('#billing-refund-policy-accept').click
  end

  describe 'a visitor who is not signed in' do
    let!(:listed_plan) do
      create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'month',
                                                       name: 'Open door', currency: 'USD', amount_cents: 500, listed: true)
    end

    before { purchase_agreements_for(host_platform) }

    it 'reads the catalog and plan detail, and is asked to sign in only to buy', :aggregate_failures do
      visit "/#{locale}/billing/catalog"

      expect(page).to have_content('Open door')
      expect(page).to be_axe_clean.within('main').according_to(*wcag).skipping('region')

      click_link 'Subscribe Open door'
      expect(page).to have_current_path(%r{/users/sign-in}, wait: 10)
    end

    it 'comes back to checkout for that plan after signing in' do
      buyer_user
      visit "/#{locale}/billing/catalog"
      click_link 'Subscribe Open door'
      fill_in 'user[email]', with: 'user@example.test'
      fill_in 'user[password]', with: 'SecureTest123!@#'
      find('form input[type=submit].btn-primary').click

      expect(page).to have_current_path(%r{/billing/checkout/new\?.*plan_id=#{listed_plan.id}}, wait: 15)
    end
  end

  describe 'a buyer with no saved billing address' do
    let!(:cash_plan) do
      create(:better_together_billing_price,
             product: create(:better_together_billing_product, platform: host_platform, name: 'Garden plot', listed: true),
             currency: 'CAD', amount_cents: 2500)
    end

    before do
      purchase_agreements_for(host_platform)
      create_billing_address_for(create(:better_together_person))
      capybara_login_as_user
      visit "/#{locale}/billing/checkout/new?price_id=#{cash_plan.id}&payment_method=cash"
    end

    it 'types a new address, picks the country and province from the lists, and sees tax for that place', :aggregate_failures do
      expect(page).to have_css('#billing-checkout-new-address')
      fill_in 'billing-checkout-address-line1', with: '1 Water St'
      fill_in 'billing-checkout-address-postal-code', with: 'A1C 1A1'
      pick_geography(:country, 'CA')
      pick_geography(:state, 'NL')

      %w[country state].each { |level| expect_hidden_value_set("#billing_address_#{level}_select_id") }
    end
  end

  describe 'a buyer with a subscription' do
    let!(:term) { start_subscription }

    before do
      purchase_agreements_for(host_platform)
      capybara_login_as_user
      visit "/#{locale}/billing/subscriptions/#{term.id}"
    end

    it 'cancels at the end of the period and then resumes', :aggregate_failures do
      expect(page).to be_axe_clean.within('main').according_to(*wcag).skipping('region')

      accept_prompt_and_click('#subscription-cancel-btn')
      expect(page).to have_button(I18n.t('better_together.billing.subscriptions.resume'), wait: 10)
      expect(term.reload.pay_subscription.ends_at).to be_present

      expect(page).to have_button(I18n.t('better_together.billing.subscriptions.resume'))
      accept_confirm { click_button I18n.t('better_together.billing.subscriptions.resume') }
      expect(page).to have_button('subscription-cancel-btn', wait: 10)
      expect(term.reload.pay_subscription.ends_at).to be_nil
    end

    context 'when another plan is on offer' do
      let!(:bigger_plan) do
        create(:better_together_billing_plan, processor: nil, processor_price_id: nil, processor_product_id: nil, billing_interval: 'month',
                                              amount_cents: 6000, currency: 'USD', accepted_payment_methods: %w[cash store_credit],
                                              name: 'Bigger plan', listed: true)
      end

      before { visit "/#{locale}/billing/subscriptions/#{term.id}" }

      it 'asks for a change from the next period, shows it waiting, and withdraws it', :aggregate_failures do
        expect(page).to have_css('#subscription-plan-change-form')
        select('Bigger plan', from: 'subscription-plan-change-select')
        accept_prompt_and_click('#subscription-plan-change-btn')

        expect(page).to have_css('#subscription-plan-change-pending', text: 'Bigger plan', wait: 10)
        expect(term.reload.pending_plan).to eq(bigger_plan)

        accept_prompt_and_click('#subscription-plan-change-withdraw-btn')
        expect(page).to have_css('#subscription-plan-change-form', wait: 10)
        expect(term.reload.pending_plan).to be_nil
      end
    end

    it 'asks for part of the money back on a paid order, and sees the request wait', :aggregate_failures do
      order = term.periods.first.order
      visit "/#{locale}/billing/orders/#{order.id}"
      click_link I18n.t('better_together.billing.refund_requests.ask_link')

      expect(page).to have_css('#billing-refund-request-form', wait: 10)
      expect(page).to be_axe_clean.within('main').according_to(*wcag).skipping('region')
      select(find('#billing-refund-request-reason').all('option').last.text, from: 'billing-refund-request-reason')
      fill_in 'billing-refund-request-amount', with: '5.00'
      fill_in 'billing-refund-request-details', with: 'I only used it for a week'
      read_and_tick_refund_policy
      click_button 'billing-refund-request-submit'

      expect(page).to have_no_css('#billing-refund-request-form', wait: 10), -> { page.all('#billing-refund-request-error').map(&:text).join }
      expect(BetterTogether::Billing::RefundRequest.where(order:).count).to eq(1)
      expect(page).to have_css('#billing-order-refund-requests', wait: 10)
    end
  end
end
