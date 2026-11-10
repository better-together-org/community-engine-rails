# frozen_string_literal: true

require 'rails_helper'

# Paying for a plan in parts at checkout: some by store credit, some in cash, and a subscription renewed by a chosen way.
RSpec.describe 'Paying in parts at checkout' do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("checkout-parts-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
  let(:buyer_address) { create_billing_address_for(buyer) }
  let(:steward) { create(:better_together_person) }
  let(:plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash store_credit],
                                                     billing_interval: 'one_time', currency: 'USD', amount_cents: 4000)
  end
  let(:monthly) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash store_credit], billing_interval: 'month',
                                                     currency: 'USD', amount_cents: 4000)
  end
  let(:agreements) { BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform) }

  def new_path(chosen = plan, **params) = better_together.new_billing_checkout_path(locale:, plan_id: chosen.id, **params)
  def checkout_path = better_together.billing_checkout_path(locale:)

  # The boxes are the shared agreement mechanism's: one `<identifier>_agreement=1` parameter per ticked agreement.
  def ticks(chosen, methods, purpose)
    missing = BetterTogether::Billing::Checkout::AgreementGate.new(platform: host_platform, purpose:, signer: buyer, purchasables: [chosen],
                                                                   payment_method: methods).missing
    missing.to_h { |agreement| [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(agreement), '1'] }
  end

  def post_checkout(chosen: plan, method: 'cash', parts: {}, purpose: 'one_time', **extra)
    post checkout_path, params: { plan_id: chosen.id, payment_method: method, part_amounts: parts, **extra,
                                  **billing_address_params(buyer_address),
                                  **ticks(chosen, [method, *parts.keys], purpose) }
  end

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    host_platform.billing_processor_settings.create!(processor: 'store_credit', enabled: true, acknowledge: true,
                                                     purposes: %w[subscription one_time ticket exchange])
    agreements.each_value { |agreement| agreement.update!(lifecycle_state: 'active') }
    sign_in member
  end

  def give_credit(cents)
    BetterTogether::Billing::Credit::Grant.call(platform: host_platform, holder: buyer, amount_cents: cents, currency: 'USD',
                                                origin: 'steward_grant', actor: steward, idempotency_key: SecureRandom.uuid)
  end

  describe 'GET new' do
    it 'offers credit for part of the price, with its cap, and an amount beside each way of paying' do
      give_credit(1500)

      get new_path

      expect(response.body).to include('billing-checkout-parts', 'billing-checkout-part-cash', 'billing-checkout-part-store_credit',
                                       'billing-checkout-part-store_credit-cap')
      expect_html_content('up to US$15.00')
    end

    it 'lists credit with the reason when the buyer has none, and offers no amounts' do
      get new_path

      expect(response.body).to include('billing-checkout-method-store_credit-reason')
      expect(response.body).not_to include('billing-checkout-parts')
    end

    it 'asks what a subscription renews with' do
      get new_path(monthly)

      expect(response.body).to include('billing-checkout-renew-with-select')
    end
  end

  describe 'POST create' do
    it 'places the order with credit for the amount given and cash for the rest' do
      give_credit(1500)

      post_checkout(parts: { 'store_credit' => '10.00' })

      order = BetterTogether::Billing::Order.last
      expect(response).to redirect_to(better_together.billing_order_path(order, locale:))
      expect(order).to be_partially_paid
      paid_by = order.payments.map { |payment| [payment.processor, payment.amount_cents] }
      expect(paid_by).to contain_exactly(['store_credit', 1000], ['cash', 3000])
    end

    it 'places a plain single-way order as before when no amounts are given' do
      post_checkout

      order = BetterTogether::Billing::Order.last
      expect(order.payments.map { |payment| [payment.processor, payment.amount_cents] }).to eq([['cash', 4000]])
    end

    it 'refuses amounts that cover the whole price, and credit the buyer does not have, placing nothing' do
      give_credit(1500)

      post_checkout(parts: { 'store_credit' => '40.00' })
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('billing-checkout-error')

      post_checkout(parts: { 'store_credit' => '20.00' })
      expect(response).to have_http_status(:unprocessable_content)
      expect(BetterTogether::Billing::Order.count).to eq(0)
      expect(BetterTogether::Billing::Credit.find_account(platform: host_platform, holder: buyer, currency: 'USD').balance_cents).to eq(1500)
    end

    it 'stores what a subscription renews with, from the ways the platform settles itself' do
      post_checkout(chosen: monthly, purpose: 'subscription', renew_with: 'store_credit')

      expect(BetterTogether::Billing::Order.last.renewal_payment_method).to eq('store_credit')
    end

    it 'ignores a renewal way it does not offer' do
      post_checkout(chosen: monthly, purpose: 'subscription', renew_with: 'fake')

      expect(BetterTogether::Billing::Order.last.renewal_payment_method).to be_nil
    end
  end
end
