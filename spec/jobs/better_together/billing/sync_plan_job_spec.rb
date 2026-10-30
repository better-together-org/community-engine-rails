# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SyncPlanJob do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) }
  let(:plan) { create(:better_together_billing_plan, :unlinked, name: 'Hosted') }

  before { BetterTogether::Billing.register_processor(:fake, -> { adapter }) }

  it 'runs on the billing queue' do
    expect(described_class.new.queue_name).to eq(BetterTogether::Billing::ApplicationJob.new.queue_name)
  end

  it 'creates the processor objects and stores the result on the plan' do
    described_class.perform_now(plan.id)

    expect(plan.reload).to have_attributes(sync_status: 'synced', sync_error: nil)
    expect(plan.processor_price_id).to start_with('price_')
    expect(plan.processor_product_id).to start_with('prod_')
    expect(plan.synced_to_processor_at).to be_present
  end

  it 'gives the adapter the plan platform context and a stable idempotency key' do
    described_class.perform_now(plan.id)

    call = adapter.calls.find { |name, *| name == :sync_plan }
    expect(call[1]).to have_attributes(platform: host_platform, processor: :fake)
    expect(call[3]).to eq("bt-plan-create-#{plan.id}")
  end

  it 'uses the same key when a retry runs again, so the processor creates one price' do
    described_class.perform_now(plan.id)
    plan.update_columns(processor_price_id: nil, sync_status: 'pending') # rubocop:disable Rails/SkipsModelValidations
    described_class.perform_now(plan.id)

    keys = adapter.calls.select { |name, *| name == :sync_plan }.map(&:last)
    expect(keys.uniq.size).to eq(1)
  end

  it 'does not enqueue another sync from storing the result' do
    plan # created (and its first push enqueued) before the job runs
    expect { described_class.perform_now(plan.id) }.not_to have_enqueued_job(described_class)
  end

  it 'ignores a plan that no longer exists' do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
    expect(adapter.calls).to be_empty
  end

  it 'raises when the processor is not set up for the plan, so the retry policy applies' do
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })

    expect { described_class.new.perform(plan.id) }.to raise_error(described_class::NotConfiguredError)
  end

  describe 'when retries run out' do
    let(:failing_job) { described_class.new(plan.id) }

    it 'records a short code a steward can read, never the processor text' do
      error = BetterTogether::Billing::ProcessorAdapter::LookupError.new('secret vendor text')

      failing_job.send(:record_failure, error)

      expect(plan.reload).to have_attributes(sync_status: 'failed', sync_error: 'processor_unavailable')
    end

    it 'records a generic code for any other error' do
      failing_job.send(:record_failure, RuntimeError.new('boom'))

      expect(plan.reload).to have_attributes(sync_status: 'failed', sync_error: 'processor_error')
    end

    it 'records not_configured when the processor was never set up' do
      failing_job.send(:record_failure, described_class::NotConfiguredError.new)

      expect(plan.reload.sync_error).to eq('not_configured')
    end

    it 'does nothing for a plan that is gone' do
      job = described_class.new(SecureRandom.uuid)

      expect { job.send(:record_failure, RuntimeError.new('x')) }.not_to raise_error
    end
  end

  it 'is retried by ActiveJob when the adapter fails' do
    plan.update_columns(name: 'boom plan') # rubocop:disable Rails/SkipsModelValidations

    expect { described_class.perform_now(plan.id) }.to have_enqueued_job(described_class)
  end
end
