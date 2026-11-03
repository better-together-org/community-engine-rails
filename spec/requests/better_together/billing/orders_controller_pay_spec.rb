# frozen_string_literal: true

require 'rails_helper'

# Paying an order through a processor, from the buyer's own order page.
RSpec.describe BetterTogether::Billing::OrdersController do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("pay-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:stranger) { find_or_create_test_user("pay-stranger-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
  let!(:order) { place_order(payment_method: 'fake') }
  let(:payment) { order.payments.first }

  def pay_path(record = order) = better_together.pay_billing_order_path(record, locale:)
  def return_path(record = order, **params) = better_together.checkout_return_billing_order_path(record, locale:, **params)
  def order_path(record = order) = better_together.billing_order_path(record, locale:)

  it 'sends a visitor to sign in' do
    get pay_path

    expect(response).to have_http_status(:found)
    expect(response.location).not_to start_with('https://fake.test')
  end

  context 'when signed in as the buyer' do
    before { sign_in member }

    it 'shows what to pay and a button that leads to the processor, with stable ids' do
      get order_path

      expect(response.body).to include('billing-order-pay-card', 'billing-order-pay-btn', 'billing-order-pay-hint')
      expect(response.body).to include(pay_path)
    end

    it 'shows no button while the processor has the payment in flight, and says so' do
      payment.update!(status: 'processing')

      get order_path

      expect(response.body).to include('billing-order-pay-card')
      expect(response.body).not_to include('billing-order-pay-btn')
      expect_html_content(I18n.t('better_together.billing.orders.pay_processing'))
    end

    it 'shows nothing to pay once it is paid' do
      BetterTogether::Billing::Payments::Succeed.call(payment, reference: 'ch_1')

      get order_path

      expect(response.body).not_to include('billing-order-pay-card')
    end

    it 'redirects to the processor\'s checkout' do
      get pay_path

      expect(response).to redirect_to("https://fake.test/checkout/checkout:#{payment.id}")
    end

    it 'goes back to the order, with a message, when there is nothing to pay or the processor gives no safe address' do
      allow(adapter).to receive(:create_checkout_session)
        .and_return(BetterTogether::Billing::CheckoutSession.new(url: 'http://evil.test/x', reference: 'cs_x'))

      get pay_path

      expect(response).to redirect_to(order_path)
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.orders.pay_unavailable'))
    end

    it 'brings the buyer back to the order after the processor, saying whether it is paid yet' do
      get pay_path

      get return_path(stripe_checkout_session_id: payment.reload.processor_session_reference)

      expect(response).to redirect_to(order_path)
      expect(flash[:notice]).to eq(I18n.t('better_together.billing.orders.return_paid'))
    end

    it 'says it is confirming when the processor does not yet say paid' do
      get pay_path
      allow(adapter).to receive(:sync_checkout_session).and_return({ status: 'unpaid' })

      get return_path(session_id: payment.reload.processor_session_reference)

      expect(flash[:notice]).to eq(I18n.t('better_together.billing.orders.return_pending'))
    end

    it 'does not believe a session that is not the one sent for this order' do
      get return_path(session_id: 'cs_someone_elses')

      expect(response).to redirect_to(order_path)
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.orders.pay_unavailable'))
      expect(adapter.calls.map(&:first)).not_to include(:sync_checkout_session)
    end

    it 'never marks the payment paid itself: the processor\'s webhook decides' do
      get pay_path
      get return_path(session_id: payment.reload.processor_session_reference)

      expect(payment.reload).to be_pending
      expect(order.reload).to be_awaiting_payment
    end
  end

  context 'when signed in as someone else' do
    before { sign_in stranger }

    it 'is a 404 for another buyer\'s order, to pay it or to return to it' do
      get pay_path
      expect(response).to have_http_status(:not_found)

      get return_path(session_id: 'cs_x')
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'is a 404 while billing is off' do
    sign_in member
    allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

    get pay_path

    expect(response).to have_http_status(:not_found)
  end
end
