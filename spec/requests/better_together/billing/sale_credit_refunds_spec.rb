# frozen_string_literal: true

require 'rails_helper'

# A steward returns what a buyer paid from store credit: it goes back onto their credit, never out as cash.
RSpec.describe BetterTogether::Billing::SaleRefundsController, 'for store credit' do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:credit) { BetterTogether::Billing::Credit }
  let(:order) { place_order(payment_method: 'store_credit') }
  let(:payment) { order.payments.sole }

  def refund_path(record = order) = better_together.billing_sale_refund_path(record, locale:)
  def sale_path(record = order) = better_together.billing_sale_path(record, locale:)
  def balance = credit.find_account(platform: host_platform, holder: buyer, currency: 'USD').balance_cents

  before do
    host_platform.billing_processor_settings.create!(processor: 'store_credit', enabled: true, acknowledge: true,
                                                     purposes: %w[one_time subscription])
    credit::Grant.call(platform: host_platform, holder: buyer, amount_cents: 6000, currency: 'USD', origin: 'steward_grant',
                       actor: steward, idempotency_key: 'seed')
    order
  end

  it 'shows a steward a form to return the credit, with stable ids' do
    sign_in steward_user

    get sale_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("credit_refund_billing_payment_#{payment.id}",
                                     "billing-sale-credit-refund-form-#{payment.id}", "billing-sale-credit-refund-btn-#{payment.id}")
  end

  it 'turns the buyer away' do
    sign_in buyer_user

    post refund_path, params: { payment_id: payment.id, token: 'a' }

    expect(payment.reload.refunds).to be_empty
    expect(balance).to eq(1500)
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'puts the money back on the buyer\'s credit, in full when no amount is given' do
      post refund_path, params: { payment_id: payment.id, token: 'a', reason: 'requested_by_buyer' }

      expect(response).to redirect_to(sale_path)
      expect(payment.reload.refunds.first).to have_attributes(amount_cents: 4500, status: 'succeeded', recorded_by: steward)
      expect(order.reload).to be_refunded
      expect(balance).to eq(6000)
    end

    it 'returns part of it from an amount in dollars, and a double click once' do
      2.times { post refund_path, params: { payment_id: payment.id, token: 'same', amount: '10' } }

      expect(payment.reload.refunds.count).to eq(1)
      expect(balance).to eq(2500)
    end

    it 'shows no form once all of it is back' do
      post refund_path, params: { payment_id: payment.id, token: 'a' }

      get sale_path

      expect(response.body).not_to include("billing-sale-credit-refund-form-#{payment.id}")
    end
  end
end
