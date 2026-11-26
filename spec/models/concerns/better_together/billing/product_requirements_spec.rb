# frozen_string_literal: true

require 'rails_helper'

# What a steward ticks on the product form becomes purchase requirements on the product.
RSpec.describe BetterTogether::Billing::ProductRequirements do
  let!(:host_platform) { configure_host_platform }
  let(:cash) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }
  let(:monthly) { create(:better_together_billing_plan, **cash) }
  let(:annual) { create(:better_together_billing_plan, **cash, billing_interval: 'year') }
  let(:product) { create(:better_together_billing_product, platform: host_platform) }
  let(:rules) { BetterTogether::Billing::PurchaseRequirement.for_dependent(product) }

  it 'sells on its own when nothing is ticked' do
    product.update!(needs_any_plan: false, needed_plan_ids: [])

    expect(product.extra?).to be(false)
  end

  it 'stores one rule for any plan' do
    product.update!(needs_any_plan: '1')

    expect(rules.sole).to have_attributes(prerequisite_kind: 'plan', prerequisite: nil)
    expect(product.needs_any_plan?).to be(true)
  end

  it 'stores one rule for each ticked plan and takes back the ones that are unticked' do
    product.update!(needed_plan_ids: [monthly.id, annual.id])
    expect(rules.map(&:prerequisite)).to contain_exactly(monthly, annual)

    product.update!(needed_plan_ids: [annual.id])
    expect(rules.reload.map(&:prerequisite)).to eq([annual])
    expect(product.needed_plan_ids).to eq([annual.id])
  end

  it 'ignores a plan of another platform' do
    foreign = create(:better_together_billing_plan, platform: create(:better_together_platform))
    product.update!(needed_plan_ids: [foreign.id])

    expect(rules).to be_empty
  end

  it 'leaves the rules alone when the form says nothing about them' do
    product.update!(needed_plan_ids: [monthly.id])
    product.update!(name: 'Renamed')

    expect(rules.count).to eq(1)
  end
end
