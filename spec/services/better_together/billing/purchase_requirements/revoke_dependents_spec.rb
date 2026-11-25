# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PurchaseRequirements::RevokeDependents do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:cash) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }
  let(:prerequisite) { create(:better_together_billing_plan, :one_time, **cash, amount_cents: 2000) }
  let(:dependent) { create(:better_together_billing_plan, :one_time, **cash, amount_cents: 700) }

  let(:extra) { create(:better_together_billing_plan, :one_time, **cash, amount_cents: 300, add_on: true) }

  def bought(purchasable)
    pay_manually(place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: }]))
  end

  it 'returns the dependent lines to take back what it gave once the prerequisite order is refunded' do
    create(:better_together_billing_purchase_requirement, dependent:, prerequisite:, on_prerequisite_end: 'revoke')
    pre_order = bought(prerequisite)
    dep_order = bought(dependent)
    pre_order.update!(status: 'refunded')

    expect(described_class.call(order: pre_order)).to eq(dep_order.line_items.to_a)
  end

  it 'leaves a dependent alone when its rule keeps it' do
    create(:better_together_billing_purchase_requirement, dependent:, prerequisite:, on_prerequisite_end: 'keep')
    pre_order = bought(prerequisite)
    bought(dependent)
    pre_order.update!(status: 'refunded')

    expect(described_class.call(order: pre_order)).to be_empty
  end

  it 'takes back a dependent whose rule asks for any plan once the buyer holds none' do
    create(:better_together_billing_purchase_requirement, :for_any_plan, dependent: extra, on_prerequisite_end: 'revoke')
    pre_order = bought(prerequisite)
    dep_order = bought(extra)
    pre_order.update!(status: 'refunded')

    expect(described_class.call(order: pre_order)).to eq(dep_order.line_items.to_a)
  end

  it 'keeps a kind-rule dependent while the buyer still holds another plan' do
    create(:better_together_billing_purchase_requirement, :for_any_plan, dependent: extra, on_prerequisite_end: 'revoke')
    bought(create(:better_together_billing_plan, :one_time, **cash, amount_cents: 900))
    pre_order = bought(prerequisite)
    bought(extra)
    pre_order.update!(status: 'refunded')

    expect(described_class.call(order: pre_order)).to be_empty
  end

  it 'has a revoke_line that does nothing by default on a purchasable' do
    expect(BetterTogether::Billing::Plan.new.revoke_line(nil)).to be_nil
  end
end
