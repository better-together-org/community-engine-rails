# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Notifications do
  include_context 'with billing notifications'

  let(:order) { place_order }

  before do
    steward
    other_steward
    order # placing an order tells people; start each example from a clean inbox
    Noticed::Notification.delete_all
    Noticed::Event.delete_all
    BetterTogether::Billing::NotificationReceipt.delete_all
    clear_enqueued_jobs
  end

  it 'tells each audience of a kind, once per person' do
    deliver_now { described_class.deliver('order_paid', subject: order) }

    expect(kinds_for(buyer)).to eq(['order_paid'])
    expect(kinds_for(steward)).to eq(['order_paid'])
    expect(kinds_for(other_steward)).to eq(['order_paid'])
  end

  it 'says different things to the buyer and to the seller' do
    deliver_now { described_class.deliver('order_paid', subject: order) }

    expect(inbox(buyer).first.event.params[:audience]).to eq(:buyer)
    expect(inbox(steward).first.event.params[:audience]).to eq(:seller)
  end

  it 'does not tell anyone twice about the same thing, however often it is called' do
    2.times { deliver_now { described_class.deliver('order_paid', subject: order) } }

    expect(inbox(buyer).count).to eq(1)
    expect(BetterTogether::Billing::NotificationReceipt.where(recipient: buyer).count).to eq(1)
  end

  it 'tells again when the same subject legitimately happens again, under a different key' do
    deliver_now { described_class.deliver('payment_failed', subject: order, dedupe_key: 'attempt-1') }
    deliver_now { described_class.deliver('payment_failed', subject: order, dedupe_key: 'attempt-1') }
    deliver_now { described_class.deliver('payment_failed', subject: order, dedupe_key: 'attempt-2') }

    expect(inbox(buyer).count).to eq(2)
  end

  it 'leaves out the person who did it' do
    deliver_now { described_class.deliver('order_cancelled', subject: order, actor: steward) }

    expect(kinds_for(steward)).to be_empty
    expect(kinds_for(other_steward)).to eq(['order_cancelled'])
  end

  it 'keeps a receipt on the order\'s platform for each person told' do
    described_class.deliver('order_paid', subject: order)

    receipts = BetterTogether::Billing::NotificationReceipt.where(kind: 'order_paid')
    expect(receipts.map(&:platform_id).uniq).to eq([host_platform.id])
    expect(receipts.map(&:audience)).to include('buyer', 'seller')
  end

  it 'refuses a kind it does not know' do
    expect { described_class.deliver('stripe_invoice_paid', subject: order) }.to raise_error(ArgumentError, /unknown notification kind/)
  end

  it 'waits for the surrounding transaction to commit, and says nothing if it rolls back' do
    BetterTogether::Billing::Order.transaction(requires_new: true) do
      described_class.deliver('order_paid', subject: order)
      expect(BetterTogether::Billing::NotificationReceipt.count).to eq(0)
      raise ActiveRecord::Rollback
    end

    expect(BetterTogether::Billing::NotificationReceipt.count).to eq(0)
  end

  it 'never fails the work that triggered it, but logs and reports the failure' do
    allow(BetterTogether::Billing::Notifier).to receive(:with).and_raise(StandardError, 'queue is down')
    allow(BetterTogether).to receive(:report_error)

    expect { described_class.deliver('order_paid', subject: order) }.not_to raise_error
    expect(BetterTogether).to have_received(:report_error).with(an_instance_of(StandardError), anything)
  end

  it 'leaves no receipt behind when it could not send, so a retry can tell them' do
    allow(BetterTogether::Billing::Notifier).to receive(:with).and_raise(StandardError, 'queue is down')

    described_class.deliver('order_paid', subject: order)

    expect(BetterTogether::Billing::NotificationReceipt.count).to eq(0)
  end

  it 'sends nothing when there is nobody to tell' do
    BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
    sold = create(:better_together_billing_order, seller: create(:better_together_community))

    expect { deliver_now { described_class.deliver('dispute_opened', subject: sold) } }.not_to change(Noticed::Notification, :count)
  end
end
