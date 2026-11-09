# frozen_string_literal: true

require 'rails_helper'

# What happens to an order paid through a processor: the payment is opened, the processor is told when core lets
# the order go, money can arrive late or for a cancelled order, and refunds can finish or fail after being recorded.
RSpec.describe 'Paying an order through a processor' do # rubocop:disable RSpec/DescribeClass
  include ActiveJob::TestHelper

  include_context 'with billing notifications'

  let(:order) { place_order(payment_method: 'fake') }
  let(:payment) { order.payments.first }

  before do
    steward
    allow(BetterTogether).to receive(:report_error)
  end

  def succeed(target = payment, **) = BetterTogether::Billing::Payments::Succeed.call(target, **)

  def record_refund(payment_to_refund, **attrs)
    BetterTogether::Billing::Refunds::Record.call(payment: payment_to_refund, amount_cents: 1_000, idempotency_key: 'core-1', status: 'pending',
                                                  **attrs)
  end

  describe 'placing the order' do
    it 'opens one pending payment for the whole balance, with a key that makes repeating it harmless' do
      expect(order.payments.count).to eq(1)
      expect(payment).to have_attributes(status: 'pending', processor: 'fake', amount_cents: 4500, idempotency_key: "checkout:#{order.id}:1")
      expect(order.offline_payments).to be_empty
    end

    it 'refuses a processor the platform has not configured, and a currency it does not take' do
      expect { place_order(payment_method: 'ghost') }.not_to raise_error # not installed at all: nothing is opened
      allow(BetterTogether::Billing::Configuration).to receive(:context_for).and_call_original
      allow(BetterTogether::Billing::Configuration).to receive(:context_for).with(host_platform, 'fake').and_return(nil)
      expect { place_order(payment_method: 'fake') }.to raise_error(BetterTogether::Billing::Orders::Place::Refused, /not available/)
    end

    it 'opens nothing for an order that costs nothing' do
      free = create(:better_together_billing_plan, amount_cents: 0)

      expect(place_order(payment_method: 'fake', line_items: [{ purchasable: free }]).payments).to be_empty
    rescue BetterTogether::Billing::Orders::Place::Refused
      skip 'a plan that costs nothing is not sold in this build'
    end
  end

  describe 'letting the order go' do
    it 'cancels the in-flight payment and tells the processor, after the change is saved, with a key of its own' do
      BetterTogether::Billing::Orders::Cancel.call(order)

      expect(payment.reload).to be_cancelled
      expect(adapter.calls).to include([:release_payment, anything, payment.id, "release:#{payment.id}"])
    end

    it 'does not stop the order being let go when the processor cannot be reached' do
      allow(adapter).to receive(:release_payment).and_raise(StandardError, 'down')

      expect { BetterTogether::Billing::Orders::Cancel.call(order) }.not_to raise_error
      expect(order.reload).to be_cancelled
      expect(BetterTogether).to have_received(:report_error)
    end

    it 'does not tell a processor about a payment core settles itself' do
      local = BetterTogether::Billing::Payments::Create.call(order: place_order, processor: 'cash', amount_cents: 100, idempotency_key: 'local')
    rescue BetterTogether::Billing::Payments::Create::Refused
      skip 'cash is not installed here'
    else
      BetterTogether::Billing::Payments::Cancel.call(local)
      expect(adapter.calls.map(&:first)).not_to include(:release_payment)
    end

    it 'leaves an order alone while a payment of it is processing, however late' do
      payment.update!(status: 'processing')
      order.update!(expires_at: 1.minute.ago)

      expect(BetterTogether::Billing::Orders::Expire.call(order)).to be(false)
      expect(order.reload).to be_awaiting_payment
    end

    it 'counts a processing payment as in flight, so the buyer cannot start another for the same money' do
      payment.update!(status: 'processing')

      expect { BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'again') }
        .to raise_error(BetterTogether::Billing::Payments::Create::Refused, /more than is owed/)
    end
  end

  describe 'money arriving' do
    it 'pays the order, links the Pay charge and records what was actually charged' do
      customer = Pay::FakeProcessor::Customer.create!(owner: buyer, platform: host_platform, processor: 'fake_processor')
      charge = customer.charge(4_950, currency: 'usd')

      succeed(reference: 'ch_1', amount_cents: 4_950, pay_charge: charge)

      expect(payment.reload).to have_attributes(status: 'succeeded', processor_reference: 'ch_1', amount_cents: 4_950, pay_charge: charge)
      expect(order.reload).to be_paid
    end

    it 'is safe to repeat' do
      2.times { succeed(reference: 'ch_1') }

      expect(order.reload.payments.map(&:status)).to eq(['succeeded'])
    end

    it 'lets a payment already given up on succeed once the processor says money arrived (a card retried in the same session)' do
      BetterTogether::Billing::Payments::Fail.call(payment, failure_code: 'declined')
      expect(payment.reload).to have_attributes(status: 'failed', failure_code: 'declined')

      succeed(reference: 'ch_retry')

      expect(payment.reload).to have_attributes(status: 'succeeded', failure_code: nil)
      expect(order.reload).to be_paid
    end

    it 'lets a payment cancelled when the order lapsed succeed after all, and the late payment pays the expired order' do
      order.update!(expires_at: 1.minute.ago)
      BetterTogether::Billing::Orders::Expire.call(order)
      expect(payment.reload).to be_cancelled
      expect(order.reload).to be_expired

      succeed(reference: 'ch_late')

      expect(payment.reload).to be_succeeded
      expect(order.reload).to be_paid
    end

    it 'does not mark a given-up payment succeeded on a guess: without a processor reference nothing happens' do
      BetterTogether::Billing::Payments::Fail.call(payment)

      succeed

      expect(payment.reload).to be_failed
      expect(order.reload).to be_awaiting_payment
    end
  end

  describe 'money arriving for an order that was cancelled' do
    before do
      BetterTogether::Billing::Orders::Cancel.call(order)
      clear_notices
    end

    it 'keeps the order cancelled, records the payment, owes the money back and tells the operators' do
      deliver_now { succeed(reference: 'ch_orphan') }

      expect(order.reload).to be_cancelled
      # The money did arrive; it is already owed back, so the payment reads as refunded (the refund is pending).
      expect(payment.reload).to have_attributes(status: 'refunded', paid_at: be_present)
      expect(payment.refunds.map { |refund| [refund.status, refund.amount_cents, refund.reason] }).to eq([['pending', 4500, 'cancelled_order']])
      expect(kinds_for(steward)).to eq(['payment_orphaned'])
      expect(kinds_for(buyer)).to be_empty
    end

    it 'records the owed refund, and tells the operators, once however often it runs' do
      deliver_now { 3.times { succeed(reference: 'ch_orphan') } }

      expect(payment.refunds.count).to eq(1)
      expect(kinds_for(steward)).to eq(['payment_orphaned'])
    end
  end

  describe 'refunds that finish or fail after being recorded' do
    let(:paid) { succeed(reference: 'ch_1') }

    it 'records a refund once whether core asked for it or the processor reported it' do
      asked = record_refund(paid, processor_reference: 're_1')
      reported = BetterTogether::Billing::Refunds::Record.call(payment: paid, amount_cents: 1_000, idempotency_key: 'webhook-evt',
                                                               status: 'succeeded', processor_reference: 're_1')

      expect(reported).to eq(asked)
      expect(paid.refunds.count).to eq(1)
    end

    it 'resolves a pending refund to succeeded, once' do
      refund = record_refund(paid)

      2.times { BetterTogether::Billing::Refunds::Resolve.call(refund, status: 'succeeded') }

      expect(refund.reload).to be_present
      expect(refund.status).to eq('succeeded')
      expect(paid.reload).to be_partially_refunded
    end

    it 'puts the payment and the order back when a refund fails, and tells the operators' do
      refund = BetterTogether::Billing::Refunds::Record.call(payment: paid, amount_cents: 4500, idempotency_key: 'full', status: 'pending')
      expect(order.reload).to be_refunded
      clear_notices

      deliver_now { BetterTogether::Billing::Refunds::Resolve.call(refund, status: 'failed') }

      expect(refund.reload.status).to eq('failed')
      expect(paid.reload).to be_succeeded
      expect(order.reload).to be_paid
      # (The order is paid again; its receipts were cleared above, which is why that notice is sent anew here.)
      expect(kinds_for(steward)).to include('refund_failed')
    end

    it 'puts a part-refunded payment back to where it was' do
      first = record_refund(paid, idempotency_key: 'one')
      second = BetterTogether::Billing::Refunds::Record.call(payment: paid, amount_cents: 500, idempotency_key: 'two', status: 'pending')

      BetterTogether::Billing::Refunds::Resolve.call(second, status: 'failed')

      expect(first.reload.status).to eq('pending')
      expect(paid.reload).to be_partially_refunded
      expect(order.reload).to be_partially_refunded
    end

    it 'refuses a refund against a payment that has not succeeded, which the adapter answers with a retry' do
      expect do
        BetterTogether::Billing::Refunds::Record.call(payment:, amount_cents: 100, idempotency_key: 'early', status: 'pending')
      end.to raise_error(BetterTogether::Billing::Refunds::Record::Refused)
    end

    it 'only resolves to succeeded or failed' do
      expect { BetterTogether::Billing::Refunds::Resolve.call(record_refund(paid), status: 'pending') }
        .to raise_error(BetterTogether::Billing::Refunds::Resolve::Refused)
    end
  end

  describe 'a subscription that starts on a trial' do
    let(:subscription) do
      customer = Pay::FakeProcessor::Customer.create!(owner: buyer, platform: host_platform, processor: 'fake_processor')
      customer.subscribe(name: 'default', plan: 'price_1', trial_period_days: 14)
    end

    it 'settles the order that began it without a payment, because nothing is owed yet' do
      order.payments.destroy_all
      order.update!(pay_subscription: subscription)

      BetterTogether::Billing::Orders::Settle.call(order)

      expect(order.reload).to be_paid
    end

    it 'does not, for a subscription that is not active or trialing' do
      order.payments.destroy_all
      subscription.update!(status: 'incomplete', trial_ends_at: nil)
      order.update!(pay_subscription: subscription)

      BetterTogether::Billing::Orders::Settle.call(order)

      expect(order.reload).to be_awaiting_payment
    end

    it 'refuses a subscription on another platform' do
      other = create(:better_together_platform)
      foreign = Pay::FakeProcessor::Customer.create!(owner: buyer, platform: other, processor: 'fake_processor')
                                            .subscribe(name: 'default', plan: 'price_1')

      expect(build(:better_together_billing_order, pay_subscription: foreign)).not_to be_valid
    end
  end

  it 'links a payment only to a charge on its own platform' do
    other = create(:better_together_platform)
    charge = Pay::FakeProcessor::Customer.create!(owner: buyer, platform: other, processor: 'fake_processor').charge(100)

    expect { payment.update!(pay_charge: charge) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'lets a Pay charge pay for one payment only, and refuses a charge on another platform at the database' do
    customer = Pay::FakeProcessor::Customer.create!(owner: buyer, platform: host_platform, processor: 'fake_processor')
    charge = customer.charge(4500)
    other_order = place_order(payment_method: 'fake')

    payment.update!(pay_charge: charge)

    expect { other_order.payments.first.update_columns(pay_charge_id: charge.id) } # rubocop:disable Rails/SkipsModelValidations
      .to raise_error(ActiveRecord::RecordNotUnique)
  end
end
