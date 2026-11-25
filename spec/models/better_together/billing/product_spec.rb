# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Product do
  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }

  it 'has a valid factory' do
    expect(build(:better_together_billing_product)).to be_valid
  end

  it 'needs a name and an identifier' do
    product = build(:better_together_billing_product, name: nil, identifier: nil)

    expect(product).not_to be_valid
  end

  it 'keeps an identifier unique on a platform' do
    create(:better_together_billing_product, identifier: 'topup')

    expect(build(:better_together_billing_product, identifier: 'topup')).not_to be_valid
  end

  it 'refuses a type outside the allow-list' do
    product = build(:better_together_billing_product)
    product.type = 'Kernel'

    expect(product).not_to be_valid
  end

  describe 'lifetime' do
    it 'defaults to until used, with no end date' do
      product = create(:better_together_billing_product)

      expect(product).to be_until_used
      expect(product.ends_at_for(Time.zone.now)).to be_nil
    end

    it 'needs a length and unit for a fixed term, and gives the end date' do
      expect(build(:better_together_billing_product, lifetime: 'fixed_term')).not_to be_valid

      product = create(:better_together_billing_product, :fixed_term)
      time = Time.zone.local(2026, 1, 15)

      expect(product.ends_at_for(time)).to eq(Time.zone.local(2027, 1, 15))
    end

    it 'refuses a term on an until used product' do
      product = build(:better_together_billing_product, term_length: 3, term_unit: 'month')

      expect(product).not_to be_valid
    end

    it 'refuses an unknown lifetime' do
      expect(build(:better_together_billing_product, lifetime: 'forever')).not_to be_valid
    end
  end

  describe '#current_price' do
    it 'is the newest active price' do
      product = create(:better_together_billing_product)
      old = create(:better_together_billing_price, product:, amount_cents: 500)
      fresh = create(:better_together_billing_price, product:, amount_cents: 700)
      old.archive!

      expect(product.current_price).to eq(fresh)
    end
  end

  it 'translates its name, description and summary' do
    product = create(:better_together_billing_product)
    product.update!(name_fr: 'Stockage', summary_fr: 'Plus de place')

    expect([product.name(locale: :fr), product.summary(locale: :fr)]).to eq(['Stockage', 'Plus de place'])
  end

  describe 'grants' do
    let(:product) { create(:better_together_billing_product) }
    let(:quota) { { 'quota_type' => 'media_storage', 'amount' => 100 } }

    it 'can include a grant, once per thing' do
      grant = product.grants.create!(platform_id: product.platform_id, kind: 'quota_allowance', parameters: quota)

      expect(grant.owner).to eq(product)
      expect(product.grants.build(platform_id: product.platform_id, kind: 'quota_allowance', parameters: quota)).not_to be_valid
    end

    it 'refuses a grant that belongs to both a plan and a product, or to neither' do
      plan = create(:better_together_billing_plan)
      both = BetterTogether::Billing::PlanGrant.new(platform_id: product.platform_id, kind: 'quota_allowance', parameters: quota, plan:,
                                                    product:)
      neither = BetterTogether::Billing::PlanGrant.new(platform_id: product.platform_id, kind: 'quota_allowance', parameters: quota)

      expect([both.valid?, neither.valid?]).to eq([false, false])
    end
  end
end
