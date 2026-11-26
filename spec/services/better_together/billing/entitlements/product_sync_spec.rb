# frozen_string_literal: true

require 'rails_helper'

# A product (a storage top-up): given when its order is paid, scaled by the quantity bought, ended after a fixed term,
# and taken back on a refund.
RSpec.describe BetterTogether::Billing::Entitlements::Sync, 'for a paid product order' do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:product) { create(:better_together_billing_product, name: 'Storage top-up') }
  let(:price) { create(:better_together_billing_price, product:, amount_cents: 500, currency: 'USD') }
  let(:quantity) { 1 }
  let(:order) do
    travel_to(start_time) do
      product.grants.create!(platform_id: product.platform_id, kind: 'quota_allowance',
                             parameters: { 'quota_type' => 'media_storage', 'amount' => 1000 })
      placed = place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: price, quantity: }])
      pay_manually(placed)
      follow_up
      placed.reload
    end
  end
  let(:entitlement) { host_platform.billing_entitlements.find_by(order_id: order.id) }

  def extra = BetterTogether::Quotas::Allowances.extra_for(buyer, 'media_storage')

  it 'gives what the product includes when the order is paid, with no end date' do
    expect(entitlement).to have_attributes(status: 'active', product:, plan: nil, beneficiary: buyer, ends_at: nil, quantity: 1)
    expect(extra).to eq(1000)
    expect(entitlement.item_name).to eq('Storage top-up')
  end

  context 'with three bought' do
    let(:quantity) { 3 }

    it 'multiplies the allowance by the quantity' do
      expect(entitlement.quantity).to eq(3)
      expect(extra).to eq(3000)
    end
  end

  it 'takes it back when the order is refunded' do
    entitlement
    BetterTogether::Billing::Refunds::Record.call(payment: order.payments.sole, amount_cents: 500, idempotency_key: 'p1')
    follow_up

    expect(entitlement.reload.status).to eq('revoked')
    expect(extra).to eq(0)
  end

  context 'with a fixed term' do
    let(:product) { create(:better_together_billing_product, :fixed_term, term_length: 2, term_unit: 'month') }

    it 'ends after the term, and the sweep takes the allowance back' do
      expect(entitlement.ends_at).to be_within(1.minute).of(order.paid_at + 2.months)
      expect(extra).to eq(1000)

      travel_to(order.paid_at + 3.months) do
        BetterTogether::Billing::LapseEntitlementsJob.perform_now
        expect(entitlement.reload.status).to eq('lapsed')
        expect(extra).to eq(0)
      end
    end
  end
end
