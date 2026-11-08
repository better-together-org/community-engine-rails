# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PlanSnapshot do
  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync]) }
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:plan) do
    create(:better_together_billing_plan, processor_price_id: 'price_snap', amount_cents: 4500, currency: 'USD', billing_interval: 'month')
  end

  before do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    allow(Rails).to receive(:cache).and_return(memory_cache)
  end

  def calls(name) = adapter.calls.count { |call_name, *| call_name == name }

  it 'reports the processor price and product with no drift when they agree' do
    result = described_class.call(plan)

    expect(result.price).to have_attributes(price_id: 'price_snap', amount_cents: 4500)
    expect(result.product).to be_present
    expect(result.drift).to be_empty
    expect(result.error).to be_nil
  end

  it 'names the fields that differ from the processor' do
    adapter.prices['price_snap'] = BetterTogether::Billing::PriceInfo.new(
      price_id: 'price_snap', product_id: plan.processor_product_id, amount_cents: 5000, currency: 'USD', interval: 'year'
    )

    expect(described_class.call(plan).drift).to contain_exactly(:amount_cents, :billing_interval)
  end

  it 'gives the adapter the plan platform context' do
    described_class.call(plan)

    context = adapter.calls.find { |name, *| name == :fetch_price }[1]
    expect(context).to have_attributes(platform: host_platform, processor: :fake)
  end

  it 'caches briefly, so reloading the page does not call the processor each time' do
    2.times { described_class.call(plan) }

    expect(calls(:fetch_price)).to eq(1)
  end

  it 'asks again once the plan changes' do
    described_class.call(plan)
    plan.update!(name: 'Renamed')
    described_class.call(plan)

    expect(calls(:fetch_price)).to eq(2)
  end

  it 'does not cache between platforms' do
    key = described_class.new(plan).send(:cache_key)

    expect(key).to include(host_platform.id)
  end

  it 'reports "unavailable", and caches nothing, when the processor cannot be reached' do
    plan.update_columns(processor_price_id: 'price_boom') # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.call(plan).error).to eq(:unavailable)
    expect(memory_cache.instance_variable_get(:@data)).to be_empty
  end

  it 'has nothing to show for a plan that is not linked yet' do
    unlinked = create(:better_together_billing_plan, :unlinked)

    expect(described_class.call(unlinked)).to have_attributes(error: :not_linked, drift: [])
    expect(adapter.calls).to be_empty
  end

  it 'has nothing to show when the processor cannot read plans' do
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })

    expect(described_class.call(plan).error).to eq(:not_linked)
  end

  it 'treats a price missing at the processor as no drift' do
    plan.update_columns(processor_price_id: 'price_missing_1') # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.call(plan)).to have_attributes(price: nil, drift: [])
  end
end
