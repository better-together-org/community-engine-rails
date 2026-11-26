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

  it 'refuses a tax category that belongs to another platform' do
    other = create(:better_together_platform, host: false, locality: 'local')
    foreign = create(:better_together_billing_tax_category, platform: other)
    product = build(:better_together_billing_product, tax_category: foreign)

    expect(product).not_to be_valid
    expect(product.errors.added?(:tax_category, :tax_category_other_platform)).to be(true)
    expect(build(:better_together_billing_product, tax_category: create(:better_together_billing_tax_category))).to be_valid
  end

  describe 'moving to another processor' do
    include_context 'with clean billing processors'

    let(:first) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync], processor: :first) }
    let(:second) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync], processor: :second) }
    let(:product) { create(:better_together_billing_product, platform: host_platform, processor: 'first', processor_product_id: 'prod_old') }
    let(:price) { create(:better_together_billing_price, product:, processor_price_id: 'price_old') }

    before do
      BetterTogether::Billing.register_processor(:first, -> { first })
      BetterTogether::Billing.register_processor(:second, -> { second })
      allow(BetterTogether::Billing::Configuration).to receive(:context_for).and_return(instance_double(BetterTogether::Billing::ProcessorContext))
    end

    it 'forgets the ids the old processor issued and has the new one create its own copy' do
      price
      expect { product.update!(processor: 'second') }.to have_enqueued_job(BetterTogether::Billing::SyncProductJob).with(product.id)

      expect(product.reload.processor_product_id).to be_nil
      expect(price.reload.processor_price_id).to be_nil
    end
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

    it 'refuses a grant that belongs to no product' do
      neither = BetterTogether::Billing::Grant.new(platform_id: product.platform_id, kind: 'quota_allowance', parameters: quota)

      expect(neither).not_to be_valid
    end
  end
end
