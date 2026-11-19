# frozen_string_literal: true

require 'rails_helper'

# What a subscription gives follows any change to the Pay subscription, whoever makes it.
RSpec.describe BetterTogether::Billing::PayExtensions::EntitlementSync do
  include_context 'with entitlement fixtures'

  let(:term) { start_subscription }
  let(:subscription) { term.reload.pay_subscription }

  before { term }

  def queued = enqueued_jobs.select { |job| job['job_class'] == 'BetterTogether::Billing::SyncEntitlementJob' }

  it 'queues a sync when the columns that decide access change' do
    clear_enqueued_jobs
    subscription.update!(status: 'past_due')
    subscription.update!(ends_at: 3.days.from_now)
    subscription.update!(current_period_end: 40.days.from_now)

    expect(queued.size).to eq(3)
  end

  it 'queues nothing for a change that decides nothing' do
    clear_enqueued_jobs
    subscription.update!(quantity: 2)
    subscription.update!(metadata: { 'note' => 'x' })

    expect(queued).to be_empty
  end

  it 'queues it for a subscription Pay syncs from a processor too (any Pay::Subscription)' do
    expect(Pay::Subscription.ancestors).to include(described_class)
  end

  it 'is a job that does nothing for a subscription with no terms, so any Pay subscription can be synced' do
    customer = buyer.add_payment_processor(:local, platform: host_platform).api_record
    other = customer.subscribe(name: 'x', plan: 'x', current_period_start: Time.current, current_period_end: 1.month.from_now)

    expect { BetterTogether::Billing::SyncEntitlementJob.perform_now(other.id) }.not_to raise_error
    expect(host_platform.billing_entitlements.find_by(pay_subscription_id: other.id)).to be_nil
  end

  it 'finds nothing to do for a subscription that no longer exists' do
    expect { BetterTogether::Billing::SyncEntitlementJob.perform_now(SecureRandom.uuid) }.not_to raise_error
  end
end
