# frozen_string_literal: true

require 'rails_helper'

# DOM contract for paying in parts: the identifiers that documentation screenshots and downstream tooling target.
# Runs in normal CI.
RSpec.describe 'Billing partial payments DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:dom_id) { ActionView::RecordIdentifier }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  describe 'the buyer\'s order that is partly paid' do
    let(:order) do
      give_credit(1000, holder: buyer_user.person)
      place_order(buyer: buyer_user.person, payment_method: nil,
                  payments: [{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash', amount_cents: 1500 }])
    end

    before { sign_in buyer_user }

    it 'exposes the balance, each part, the add-payment form and one cash card per part' do
      get "/#{locale}/billing/orders/#{order.id}"

      expect_ids(dom_id.dom_id(order, :balance), 'billing-order-payments', 'billing-order-add-payment', 'billing-order-add-payment-hint',
                 'billing-order-add-payment-form', 'billing-order-add-payment-method', 'billing-order-add-payment-amount',
                 'billing-order-add-payment-btn', dom_id.dom_id(order.payments.first))
      order.offline_payments.each do |offline|
        expect_ids(dom_id.dom_id(offline), "billing-offline-instructions-#{offline.id}", "billing-offline-amount-#{offline.id}",
                   "billing-offline-claim-form-#{offline.id}")
      end
    end

    it 'leaves the form out once nothing is left to pay' do
      give_credit(4000, holder: buyer_user.person)
      billing_add = BetterTogether::Billing::Orders::AddPayment
      billing_add.call(order:, payment_method: 'store_credit', idempotency_key: 'all')

      get "/#{locale}/billing/orders/#{order.id}"

      expect(response.body).not_to include('billing-order-add-payment-form')
    end
  end

  describe 'the seller\'s sale that is partly paid' do
    let(:order) do
      give_credit(1000)
      place_order(payment_method: nil,
                  payments: [{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash', amount_cents: 1500 }])
    end

    before { sign_in steward_user }

    it 'exposes the return panel, what is left to return and the credit button' do
      get "/#{locale}/billing/sales/#{order.id}"

      expect_ids(dom_id.dom_id(order, :return_payments), 'billing-sale-return-hint', 'billing-sale-return-parts',
                 dom_id.dom_id(order.payments.find_by(processor: 'store_credit'), :return_part), 'billing-sale-return-credit-btn')
    end

    it 'exposes the cancel button once nothing is against the order' do
      BetterTogether::Billing::Orders::ReturnPayments.call(order:, actor: steward)

      get "/#{locale}/billing/sales/#{order.id}"

      expect_ids(dom_id.dom_id(order, :cancel), 'billing-sale-cancel-btn')
    end
  end

  describe 'the checkout' do
    let(:plan_for_parts) do
      create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash store_credit],
                                                       billing_interval: 'month', currency: 'USD', amount_cents: 4000)
    end

    before do
      sign_in buyer_user
      give_credit(1500, holder: buyer_user.person)
    end

    it 'exposes the amount fields, their caps and the renewal choice' do
      get "/#{locale}/billing/checkout/new", params: { plan_id: plan_for_parts.id }

      expect_ids('billing-checkout-parts', 'billing-checkout-parts-hint', 'billing-checkout-part-cash', 'billing-checkout-part-store_credit',
                 'billing-checkout-part-store_credit-cap', 'billing-checkout-renew-with', 'billing-checkout-renew-with-select',
                 'billing-checkout-renew-with-hint')
    end
  end
end
