# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Price do
  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }
  let(:product) { create(:better_together_billing_product, name: 'Storage top-up') }

  it 'has a valid factory and takes its platform from the product' do
    price = create(:better_together_billing_price, product:)

    expect(price.platform_id).to eq(product.platform_id)
  end

  it 'is a registered purchasable' do
    expect(BetterTogether::Billing::Purchasable.model_names).to include('BetterTogether::Billing::Price')
  end

  it 'refuses a price on another platform from its product' do
    other = create(:better_together_platform)
    price = build(:better_together_billing_price, product:, platform: other)

    expect(price).not_to be_valid
  end

  it 'describes itself with the product name and the label' do
    price = create(:better_together_billing_price, product:, label: 'Early bird')

    expect(price.purchasable_description).to eq('Storage top-up - Early bird')
  end

  it 'takes its tax category from the product' do
    category = create(:better_together_billing_tax_category, platform: host_platform)
    product.update!(tax_category: category)

    expect(create(:better_together_billing_price, product:).purchasable_tax_category).to eq(category)
  end

  it 'cannot change its amount or currency once made' do
    price = create(:better_together_billing_price, product:, amount_cents: 500)

    expect(price.update(amount_cents: 900)).to be(false)
  end

  it 'is no longer purchasable once archived, or when its product is off' do
    price = create(:better_together_billing_price, product:)
    expect(price).to be_purchasable

    price.archive!
    expect(price).not_to be_purchasable
    expect(price).to be_archived

    other = create(:better_together_billing_price, product:)
    product.update!(active: false)
    expect(other.reload).not_to be_purchasable
  end

  it 'is fulfilled through its order, never renews, and is not an extra or a plan line' do
    price = create(:better_together_billing_price, product:)

    expect([price.fulfilled_by_order?, price.renews?, price.extra?, price.plan_line?]).to eq([true, false, false, false])
  end
end
