# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SyncProductJob do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[catalog_sync lookups]) }
  let(:product) { create(:better_together_billing_product, platform: host_platform, name: 'Top-up') }
  let!(:price) { create(:better_together_billing_price, product:, amount_cents: 500, currency: 'USD') }

  before do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    product.update_columns(processor: 'fake', sync_status: 'pending') # rubocop:disable Rails/SkipsModelValidations
  end

  it 'runs on the billing queue' do
    expect(described_class.new.queue_name).to eq(BetterTogether::Billing::ApplicationJob.new.queue_name)
  end

  it 'stores the processor product id and each price id' do
    described_class.perform_now(product.id)

    expect(product.reload).to have_attributes(sync_status: 'synced', sync_error: nil, processor_product_id: "prod_#{product.id}")
    expect(product.synced_to_processor_at).to be_present
    expect(price.reload.processor_price_id).to eq("price_#{price.id}")
  end

  it 'pushes a price added later, and leaves the first alone' do
    described_class.perform_now(product.id)
    second = create(:better_together_billing_price, product:, amount_cents: 900, currency: 'USD')
    described_class.perform_now(product.id)

    expect(second.reload.processor_price_id).to eq("price_#{second.id}")
    expect(price.reload.processor_price_id).to eq("price_#{price.id}")
  end

  it 'passes a stable idempotency key for the same state' do
    2.times { adapter.calls.clear.then { described_class.perform_now(product.id) } }
    key = adapter.calls.find { |name, *| name == :sync_catalog_item }.last

    expect(key).to start_with("bt-product-#{product.id}-")
  end

  it 'does nothing for a product with no processor' do
    product.update_columns(processor: nil) # rubocop:disable Rails/SkipsModelValidations
    described_class.perform_now(product.id)

    expect(adapter.calls).to be_empty
  end

  it 'queues a push when a price is added to a product the processor can hold' do
    product.update_columns(sync_status: 'synced') # rubocop:disable Rails/SkipsModelValidations

    expect do
      create(:better_together_billing_price, product:, amount_cents: 700, currency: 'USD')
    end.to have_enqueued_job(described_class).with(product.id)
  end

  it 'records a short failure code when the processor cannot be reached' do
    job = described_class.new(product.id)
    job.send(:record_failure, BetterTogether::Billing::ProcessorAdapter::LookupError.new)

    expect(product.reload).to have_attributes(sync_status: 'failed', sync_error: 'processor_unavailable')
  end
end
