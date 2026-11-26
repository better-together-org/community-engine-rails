# frozen_string_literal: true

require 'rails_helper'

# PS-7: one call holds a product with all its prices, whichever contract version the adapter implements.
RSpec.describe BetterTogether::Billing::CatalogSync do
  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[catalog_sync lookups]) }
  let(:product) { create(:better_together_billing_product, platform: host_platform, name: 'Top-up', processor: 'fake') }
  let(:small) { create(:better_together_billing_price, product:, amount_cents: 500, currency: 'USD') }
  let(:large) { create(:better_together_billing_price, product:, amount_cents: 1500, currency: 'USD') }
  let(:plan) { create(:better_together_billing_plan, :unlinked, name: 'Hosted') }

  before do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    [small, large]
  end

  describe 'an adapter at contract version 2' do
    it 'is given the product with every price, and returns a price for each' do
      result = described_class.call(product)

      item = adapter.calls.find { |name, *| name == :sync_catalog_item }[2]
      expect(item).to have_attributes(kind: 'product', name: 'Top-up', processor_product_id: nil)
      expect(item.prices.map(&:ref)).to contain_exactly(small.id, large.id)
      expect(result.product_id).to eq("prod_#{product.id}")
      expect(result.price_for(large.id)).to have_attributes(price_id: "price_#{large.id}", amount_cents: 1500)
    end

    it 'holds a plan as an item with one recurring price' do
      described_class.call(plan)

      item = adapter.calls.find { |name, *| name == :sync_catalog_item }[2]
      expect(item.prices.sole).to have_attributes(ref: plan.current_price.id, interval: plan.billing_interval)
    end

    it 'refuses an answer that is not a CatalogSyncResult' do
      allow(adapter).to receive(:sync_catalog_item).and_return(:nope)

      expect { described_class.call(product) }.to raise_error(TypeError, /CatalogSyncResult/)
    end
  end

  it 'refuses a record whose processor is not configured' do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    product.update_columns(processor: 'missing') # rubocop:disable Rails/SkipsModelValidations

    expect { described_class.call(product) }.to raise_error(described_class::NotConfigured)
  end
end
