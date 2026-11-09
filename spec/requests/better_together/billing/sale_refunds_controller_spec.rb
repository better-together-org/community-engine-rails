# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SaleRefundsController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }
  let(:payment) { offline.payment }

  def refund_path(record = order) = better_together.billing_sale_refund_path(record, locale:)
  def sale_path(record = order) = better_together.billing_sale_path(record, locale:)

  before do
    transition.receive(offline, by: steward)
    payment.reload
  end

  it 'sends a visitor to sign in' do
    post refund_path, params: { payment_id: payment.id, token: 'a' }

    expect(response).to have_http_status(:found)
    expect(payment.reload.refunds).to be_empty
  end

  it 'turns the buyer away' do
    sign_in buyer_user

    post refund_path, params: { payment_id: payment.id, token: 'a' }

    expect(payment.reload.refunds).to be_empty
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'records the refund the seller says they made, in full when no amount is given, and tells the buyer' do
      clear_notices
      deliver_now { post refund_path, params: { payment_id: payment.id, token: 'a', reason: 'requested_by_buyer' } }

      expect(response).to redirect_to(sale_path)
      expect(payment.reload.refunds.first).to have_attributes(amount_cents: 4500, status: 'recorded', reason: 'requested_by_buyer',
                                                              recorded_by: steward)
      expect(order.reload).to be_refunded
      expect(kinds_for(buyer)).to include('refund_recorded')
    end

    it 'records part of it from an amount in dollars' do
      post refund_path, params: { payment_id: payment.id, token: 'a', amount: '12.50' }

      expect(payment.reload.refunds.first.amount_cents).to eq(1250)
      expect(order.reload).to be_partially_refunded
    end

    it 'records a double click once' do
      2.times { post refund_path, params: { payment_id: payment.id, token: 'same', amount: '10' } }

      expect(payment.reload.refunds.count).to eq(1)
    end

    it 'refuses more than was paid, and a nonsense amount' do
      post refund_path, params: { payment_id: payment.id, token: 'a', amount: '9999' }
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.sales.refund_refused'))

      post refund_path, params: { payment_id: payment.id, token: 'b', amount: 'lots' }
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.sales.refund_refused'))
      expect(payment.reload.refunds).to be_empty
    end

    it 'does not refund a payment through a vendor from here' do
      vendor = BetterTogether::Billing::Payments::Create.call(order: place_order, processor: 'fake', amount_cents: 4500, idempotency_key: 'v')

      post refund_path(vendor.order), params: { payment_id: vendor.id, token: 'a' }

      expect(response).to have_http_status(:not_found)
    end

    it 'is a 404 for a payment of another order' do
      other = offline_for(place_offline('cash', buyer: other_buyer))

      post refund_path, params: { payment_id: other.payment_id, token: 'a' }

      expect(response).to have_http_status(:not_found)
    end

    it 'shows the form only while there is something left to refund' do
      get sale_path
      expect(response.body).to include("billing-sale-refund-form-#{order.id}")

      post refund_path, params: { payment_id: payment.id, token: 'a' }
      get sale_path
      expect(response.body).not_to include("billing-sale-refund-form-#{order.id}")
    end
  end
end
