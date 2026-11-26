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

  describe 'recurring prices' do
    it 'is one time unless it says otherwise, with no interval' do
      price = create(:better_together_billing_price, product:)

      expect(price).to have_attributes(kind: 'one_time', interval: nil, interval_count: 1, billing_interval: 'one_time')
      expect(price).not_to be_recurring
    end

    it 'recurs every interval_count intervals and reports its interval' do
      price = create(:better_together_billing_price, product:, kind: 'recurring', interval: 'month', interval_count: 3)

      expect(price).to be_recurring
      expect(price.billing_interval).to eq('month')
    end

    it 'starts a subscription and is read as a plan line, and is not given through its order' do
      price = create(:better_together_billing_price, product:, kind: 'recurring', interval: 'month')

      expect([price.renews?, price.plan_line?, price.fulfilled_by_order?, price.extra?]).to eq([true, true, false, false])
    end

    it 'refuses a recurring price with no interval, an unknown interval, or a one-time price with one' do
      expect(build(:better_together_billing_price, product:, kind: 'recurring')).not_to be_valid
      expect(build(:better_together_billing_price, product:, kind: 'recurring', interval: 'fortnight')).not_to be_valid
      expect(build(:better_together_billing_price, product:, interval: 'month')).not_to be_valid
    end

    it 'cannot change its kind or interval once made' do
      price = create(:better_together_billing_price, product:, kind: 'recurring', interval: 'month')

      expect(price.update(interval: 'year')).to be(false)
      expect(price.update(kind: 'one_time', interval: nil)).to be(false)
    end

    it 'keeps a lookup key unique on its platform, and any number may have none' do
      create(:better_together_billing_price, product:, lookup_key: 'storage-5gb')

      expect(build(:better_together_billing_price, product:, lookup_key: 'storage-5gb')).not_to be_valid
      expect(build(:better_together_billing_price, product:, lookup_key: nil)).to be_valid
    end
  end
end
