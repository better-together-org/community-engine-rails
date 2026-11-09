# frozen_string_literal: true

require 'rails_helper'

# A buyer adds a payment, or the rest, to an order that is not fully paid.
RSpec.describe BetterTogether::Billing::OrderPaymentsController do
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:order) { place_order(payment_method: 'cash') }

  def payments_path(record = order) = better_together.billing_order_payments_path(record, locale:)
  def order_path(record = order) = better_together.billing_order_path(record, locale:)

  it 'sends a visitor to sign in' do
    post payments_path, params: { payment_method: 'cash' }

    expect(response).to have_http_status(:found)
    expect(order.payments.count).to eq(1)
  end

  context 'when signed in as the buyer' do
    before { sign_in buyer_user }

    let(:order) { place_order(buyer: buyer_user.person, payment_method: 'cash') }

    it 'pays part of the order with credit, and the order page shows the rest to pay' do
      give_credit(2000, holder: buyer_user.person)

      post payments_path, params: { payment_method: 'store_credit', amount: '15.00', token: 'a' }

      expect(response).to redirect_to(order_path)
      expect(order.reload).to be_partially_paid
      expect(order.balance_cents).to eq(3000)
      expect(order.payments.find_by(processor: 'store_credit')).to have_attributes(amount_cents: 1500, status: 'succeeded')

      get order_path
      expect(response.body).to include('billing-order-add-payment-form', ActionView::RecordIdentifier.dom_id(order, :balance))
    end

    it 'uses all the credit it can when no amount is typed, and shows one card per waiting cash part' do
      give_credit(1000, holder: buyer_user.person)
      post payments_path, params: { payment_method: 'store_credit', token: 'a' }
      post payments_path, params: { payment_method: 'cheque', amount: '10.00', token: 'b' } if enable_offline('cheque', purposes: %w[one_time])

      get order_path

      expect(order.reload.payments.where(status: 'succeeded').sum(:amount_cents)).to eq(1000)
      order.offline_payments.each { |offline| expect(response.body).to include("billing-offline-claim-form-#{offline.id}") }
      expect(order.offline_payments.count).to eq(2)
    end

    it 'does the same thing once however many times the form is sent' do
      give_credit(3000, holder: buyer_user.person)

      2.times { post payments_path, params: { payment_method: 'store_credit', amount: '10.00', token: 'same' } }

      expect(order.reload.payments.where(processor: 'store_credit').count).to eq(1)
      expect(order.payments.find_by(processor: 'store_credit').amount_cents).to eq(1000)
    end

    it 'refuses an amount that is more than is left, or credit the buyer does not have, with a message and no payment' do
      post payments_path, params: { payment_method: 'store_credit', amount: '10.00', token: 'a' }
      expect(response).to redirect_to(order_path)
      expect(flash[:alert]).to be_present

      post payments_path, params: { payment_method: 'cash', amount: '999.00', token: 'b' }
      expect(flash[:alert]).to be_present
      expect(order.payments.count).to eq(1)
    end

    it 'is a 404 for an order that is not theirs' do
      other = place_order(buyer: other_buyer, payment_method: 'cash')

      post payments_path(other), params: { payment_method: 'cash' }

      expect(response).to have_http_status(:not_found)
    end

    it 'turns the request away once the order is paid in full' do
      give_credit(4500, holder: buyer_user.person)
      post payments_path, params: { payment_method: 'store_credit', token: 'a' }
      expect(order.reload).to be_paid

      post payments_path, params: { payment_method: 'cash', token: 'b' }

      expect(response).to have_http_status(:redirect)
      expect(order.payments.where(processor: 'cash').count).to eq(1)
    end
  end
end
