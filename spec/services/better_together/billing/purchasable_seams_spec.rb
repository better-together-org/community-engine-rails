# frozen_string_literal: true

require 'rails_helper'

# Pins what the order engine does today for each kind of purchasable, before one-off purchases leave Plan
# (docs/billing/purchasable_split_plan.md, PS-1). Each example describes behaviour that must survive the split,
# not how it is built today, so the later steps can change the code and keep these green.
RSpec.describe BetterTogether::Billing::Orders::Settle, '.call follow-ups by purchasable' do # rubocop:disable RSpec/SpecFilePathFormat
  include ActiveJob::TestHelper

  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:cash) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }
  let(:once_plan) { create(:better_together_billing_plan, :one_time, **cash, amount_cents: 2000) }
  let(:add_on) { create(:better_together_billing_plan, :one_time, **cash, amount_cents: 700, add_on: true) }
  let(:recurring) { create(:better_together_billing_plan, **cash, amount_cents: 1500) }

  def enqueued_kinds
    enqueued_jobs.pluck(:job).map { |job| job.to_s.demodulize }
  end

  def pay(purpose, plan)
    order = place_order(purpose:, payment_method: 'cash', line_items: [{ purchasable: plan }])
    clear_enqueued_jobs
    pay_manually(order)
    order
  end

  it 'queues the entitlement sync when a one-time plan order is paid' do
    pay('one_time', once_plan)

    expect(enqueued_kinds).to include('SyncOrderEntitlementJob')
    expect(enqueued_kinds).not_to include('SubscriptionOrderPaidJob')
  end

  it 'queues the subscription start, and no entitlement sync, when a recurring plan order is paid' do
    pay('subscription', recurring)

    expect(enqueued_kinds).to include('SubscriptionOrderPaidJob')
    expect(enqueued_kinds).not_to include('SyncOrderEntitlementJob')
  end

  # Today the sync job is queued here too, because an add-on is a one-time plan, and it finds nothing to give.
  # The split removes that needless job; what must hold is that no subscription starts and nothing is granted.
  it 'starts no subscription for an add-on bought on its own' do
    pay('one_time', add_on)

    expect(enqueued_kinds).not_to include('SubscriptionOrderPaidJob')
  end

  it 'gives an add-on only order no entitlement' do
    order = pay('one_time', add_on)
    follow_up

    expect(host_platform.billing_entitlements.where(order_id: order.id)).to be_empty
  end

  it 'queues the entitlement sync again when a one-time plan order is refunded' do
    order = pay('one_time', once_plan)
    follow_up
    clear_enqueued_jobs
    BetterTogether::Billing::Refunds::Record.call(payment: order.payments.sole, amount_cents: 2000, idempotency_key: 'seam-refund')

    expect(enqueued_kinds).to include('SyncOrderEntitlementJob')
  end
end
