# frozen_string_literal: true

require 'rails_helper'

# What the billing work tells people about, and that it does so once.
RSpec.describe 'Billing notification triggers' do # rubocop:disable RSpec/DescribeClass
  include_context 'with billing notifications'
  include_context 'with builtin billing processors'

  before do
    steward
    other_steward
    plan
  end

  def settle_with_payment(order, amount: 4500)
    payment = BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: amount,
                                                             idempotency_key: SecureRandom.hex(6))
    BetterTogether::Billing::Payments::Succeed.call(payment)
  end

  describe 'orders' do
    it 'tells the buyer and the stewards when an order is placed' do
      order = nil
      deliver_now { order = place_order }

      expect(kinds_for(buyer)).to eq(['order_placed'])
      expect(inbox(steward).first.event.title).to eq("New order #{order.number}")
      expect(inbox(buyer).first.event.title).to eq("Your order #{order.number} was placed")
    end

    it 'tells a person once, not once as buyer and again as steward, when they are both' do
      deliver_now { place_order(buyer: steward) }

      expect(kinds_for(steward)).to eq(['order_placed'])
      expect(inbox(steward).first.event.audience).to eq(:buyer)
      expect(kinds_for(other_steward)).to eq(['order_placed'])
    end

    it 'tells both sides when it is paid, once however often it is settled' do
      order = place_order
      Noticed::Notification.delete_all
      deliver_now { settle_with_payment(order) }
      2.times { deliver_now { BetterTogether::Billing::Orders::Settle.call(order) } }

      expect(kinds_for(buyer)).to eq(['order_paid'])
      expect(kinds_for(steward)).to eq(['order_paid'])
    end

    it 'does not announce a part payment as paid' do
      order = place_order
      Noticed::Notification.delete_all
      deliver_now { settle_with_payment(order, amount: 1000) }

      expect(kinds_for(buyer)).to be_empty
    end

    it 'tells both sides when it is cancelled and when it lapses' do
      cancelled = place_order
      lapsed = place_order(buyer:).tap { |order| order.update!(expires_at: 1.hour.ago) }
      Noticed::Notification.delete_all

      deliver_now do
        BetterTogether::Billing::Orders::Cancel.call(cancelled)
        BetterTogether::Billing::Orders::Expire.call(lapsed)
      end

      expect(kinds_for(buyer)).to contain_exactly('order_cancelled', 'order_expired')
      expect(kinds_for(steward)).to contain_exactly('order_cancelled', 'order_expired')
    end

    it 'tells the buyer, and the stewards, about a refund, and only the buyer about one the seller recorded' do
      order = place_order
      payment = settle_with_payment(order)
      Noticed::Notification.delete_all

      deliver_now do
        BetterTogether::Billing::Refunds::Record.call(payment:, amount_cents: 500, idempotency_key: 'r1', status: 'succeeded')
        BetterTogether::Billing::Refunds::Record.call(payment: payment.reload, amount_cents: 500, idempotency_key: 'r2', status: 'recorded')
      end

      expect(kinds_for(buyer)).to contain_exactly('refund_issued', 'refund_recorded')
      expect(kinds_for(steward)).to eq(['refund_issued'])
    end
  end

  describe 'a changed payment method' do
    it 'tells the other stewards, in the app and by email even if they turned email off, and not the person who changed it' do
      other_steward.update!(notify_by_email: false)

      deliver_now do
        host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true, changed_by: steward,
                                                         settings: { 'instructions' => 'Pay Alex at 4711 Harbour Road' })
      end

      expect(kinds_for(other_steward)).to eq(['settings_changed'])
      expect(kinds_for(steward)).to be_empty
      expect(sent_mail.map(&:to).flatten).to include(other_steward.email)
      expect(sent_mail.map { |mail| mail.html_part.body.decoded }.join).not_to include('4711')
    end

    it 'tells again about a later change, and not about a save that changed nothing' do
      setting = nil
      deliver_now do
        setting = host_platform.billing_processor_settings.create!(processor: 'cash', changed_by: steward)
        setting.update!(hold_hours: 24, changed_by: steward)
        setting.save!
      end

      expect(kinds_for(other_steward)).to eq(%w[settings_changed settings_changed])
    end
  end

  describe 'the event pipeline' do
    let(:order) { place_order }
    let(:event) do
      create(:better_together_billing_event, payload: { 'id' => 'evt_n', 'type' => 'fake.invoice.payment_failed', 'outcome' => 'alerted',
                                                        'outcome_kind' => 'payment_failed' })
    end

    before do
      order # placing it tells people; the examples below are about what the event tells them
      event
      clear_enqueued_jobs
      Noticed::Notification.delete_all
      allow(adapter).to receive(:process_event).and_return(
        BetterTogether::Billing::EventResult.new(status: :alerted, outcome_kind: :payment_failed, subject: order)
      )
    end

    it 'tells the buyer, as a critical notice, when the processor reports a failed payment' do
      deliver_now { BetterTogether::Billing::EventProcessor.call(event) }

      expect(kinds_for(buyer)).to eq(['payment_failed'])
      expect(inbox(buyer).first.event).to be_critical
    end

    it 'does not tell them again when the same event is replayed' do
      deliver_now { BetterTogether::Billing::EventProcessor.call(event) }
      event.reload.update_columns(processing_status: 'pending', claimed_at: nil) # rubocop:disable Rails/SkipsModelValidations
      deliver_now { BetterTogether::Billing::EventProcessor.call(event) }

      expect(inbox(buyer).count).to eq(1)
    end

    it 'says nothing for an outcome with no subject, or one core does not announce' do
      allow(adapter).to receive(:process_event).and_return(BetterTogether::Billing::EventResult.new(status: :processed,
                                                                                                    outcome_kind: :payment_failed))
      deliver_now { BetterTogether::Billing::EventProcessor.call(event) }

      expect(inbox(buyer)).to be_empty
    end

    it 'does not fail the event if telling people fails' do
      allow(BetterTogether::Billing::Notifier).to receive(:with).and_raise(StandardError, 'down')

      expect { BetterTogether::Billing::EventProcessor.call(event) }.not_to raise_error
      expect(event.reload).to be_alerted
    end
  end

  describe 'operations' do
    it 'tells the stewards when an event is dead-lettered' do
      event = create(:better_together_billing_event)

      deliver_now { event.dead_letter!(reason: 'retries_exhausted') }

      expect(kinds_for(steward)).to eq(['event_dead_lettered'])
      expect(inbox(steward).first.event).to be_critical
    end

    it 'tells the stewards when a plan could not be sent to the processor, once per attempt' do
      failing = create(:better_together_billing_plan, :unlinked)
      Noticed::Notification.delete_all
      job = BetterTogether::Billing::SyncPlanJob.new(failing.id)

      deliver_now { job.send(:record_failure, RuntimeError.new('x')) }

      expect(kinds_for(steward)).to eq(['plan_sync_failed'])
    end

    it 'does not tell the platform about a plan a community sells' do
      BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
      theirs = create(:better_together_billing_plan, :unlinked, seller: create(:better_together_community))
      Noticed::Notification.delete_all

      deliver_now { BetterTogether::Billing::SyncPlanJob.new(theirs.id).send(:record_failure, RuntimeError.new('x')) }

      expect(kinds_for(steward)).to be_empty
    end
  end
end
