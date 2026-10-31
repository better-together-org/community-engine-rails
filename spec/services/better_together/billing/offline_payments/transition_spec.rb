# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OfflinePayments::Transition do
  include_context 'with offline payment fixtures'

  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }

  # Placing the order told people about it; each example starts with an empty inbox.
  before do
    offline
    clear_notices
  end

  def events_for(record) = BetterTogether::Billing::Event.about(record).order(:created_at).pluck(:event_type)

  describe 'the seller confirming' do
    it 'pays the order when the buyer never claimed anything' do
      expect(offline).to have_attributes(status: 'awaiting', claimed_at: nil)

      described_class.receive(offline, by: steward)

      expect(offline.reload).to have_attributes(status: 'confirmed', confirmed_by: steward)
      expect(offline.confirmed_at).to be_present
      expect(offline.payment.reload).to be_succeeded
      expect(order.reload).to be_paid
    end

    it 'pays the order after the buyer claimed' do
      described_class.claim(offline, reference: 'sent at noon')
      described_class.receive(offline, by: steward)

      expect(offline.reload.status).to eq('confirmed')
      expect(order.reload).to be_paid
    end

    it 'pays the order after the hold ran out, taking the place again' do
      order.update!(expires_at: 1.minute.ago)
      BetterTogether::Billing::Orders::Expire.call(order)
      expect(offline.reload.status).to eq('expired')
      expect(order.reload).to be_expired

      described_class.receive(offline, by: steward)

      expect(offline.reload.status).to eq('confirmed')
      expect(order.reload).to be_paid
      expect(order.payments.map(&:status)).to contain_exactly('cancelled', 'succeeded')
      expect(offline.payment).to be_succeeded
    end

    it 'does not pay a late order when the place is gone, and tells the seller and the buyer' do
      order.update!(expires_at: 1.minute.ago)
      BetterTogether::Billing::Orders::Expire.call(order)
      clear_notices
      allow_any_instance_of(BetterTogether::Billing::Plan).to receive(:reserve!).and_raise(StandardError, 'sold out') # rubocop:disable RSpec/AnyInstance

      deliver_now { expect { described_class.receive(offline, by: steward) }.to raise_error(described_class::PlaceGone) }

      expect(offline.reload.status).to eq('expired')
      expect(order.reload).to be_expired
      expect(kinds_for(buyer)).to eq(['payment_place_gone'])
      expect(kinds_for(other_steward)).to eq(['payment_place_gone'])
    end

    it 'is harmless to repeat: it confirms once, logs once and tells once' do
      deliver_now { 2.times { described_class.receive(offline, by: steward) } }

      expect(events_for(offline)).to eq(['cash.payment_confirmed'])
      expect(kinds_for(buyer)).to contain_exactly('payment_confirmed', 'order_paid')
    end

    it 'records the seller\'s reference and the date they received it' do
      described_class.receive(offline, by: steward, reference: 'envelope 12', received_on: Date.new(2026, 10, 1))

      expect(offline.reload).to have_attributes(seller_reference: 'envelope 12', received_on: Date.new(2026, 10, 1))
      expect(offline.payment.reload.processor_reference).to eq('envelope 12')
    end

    it 'tells the buyer even though they never claimed, and does not tell the seller who did it' do
      clear_notices
      deliver_now { described_class.receive(offline, by: steward) }

      expect(kinds_for(buyer)).to include('payment_confirmed')
      expect(kinds_for(steward)).not_to include('payment_confirmed')
    end

    it 'refuses a payment that was rejected' do
      described_class.reject(offline, by: steward)

      expect { described_class.receive(offline, by: steward) }.to raise_error(described_class::NotAllowed)
    end
  end

  describe 'confirming your own purchase' do
    it 'is refused for a buyer who is not a steward' do
      own = offline_for(place_offline('cash', buyer: other_buyer))

      expect { described_class.receive(own, by: other_buyer) }.to raise_error(described_class::SelfConfirmation)
      expect(own.reload.status).to eq('awaiting')
    end

    it 'is refused for the person the purchase is on behalf of' do
      own = offline_for(place_offline('cash', on_behalf_of: other_buyer))

      expect { described_class.receive(own, by: other_buyer) }.to raise_error(described_class::SelfConfirmation)
    end

    it 'is allowed for a steward, who is accountable for the platform and logged as the person who confirmed' do
      own = offline_for(place_offline('cash', buyer: steward))

      described_class.receive(own, by: steward)

      expect(own.reload).to have_attributes(status: 'confirmed', confirmed_by: steward)
    end

    it 'does not stop someone else confirming a buyer\'s payment' do
      expect { described_class.receive(offline, by: other_steward) }.not_to raise_error
    end
  end

  describe 'the buyer claiming' do
    it 'flags the payment and tells the seller, without changing what the seller can do' do
      clear_notices
      deliver_now { described_class.claim(offline, reference: 'sent at noon') }

      expect(offline.reload).to have_attributes(status: 'claimed', buyer_reference: 'sent at noon', claim_count: 1)
      expect(offline.claimed_at).to be_present
      expect(kinds_for(steward)).to eq(['payment_claimed'])
      expect(kinds_for(buyer)).to be_empty
    end

    it 'tells the seller once however many times it is sent, and keeps the newest reference' do
      clear_notices
      deliver_now do
        described_class.claim(offline, reference: 'first')
        described_class.claim(offline, reference: 'second')
      end

      expect(kinds_for(steward)).to eq(['payment_claimed'])
      expect(offline.reload).to have_attributes(buyer_reference: 'second', claim_count: 2)
    end

    it 'keeps the reference when a later claim has none' do
      described_class.claim(offline, reference: 'first')
      described_class.claim(offline)

      expect(offline.reload.buyer_reference).to eq('first')
    end

    it 'is ignored after the seller confirmed: nothing changes and nobody is told' do
      described_class.receive(offline, by: steward)
      clear_notices

      deliver_now { described_class.claim(offline, reference: 'too late') }

      expect(offline.reload).to have_attributes(status: 'confirmed', claimed_at: nil, buyer_reference: nil)
      expect(order.reload).to be_paid
      expect(kinds_for(steward)).to be_empty
    end

    it 'is recorded after the hold ran out without changing its status, so the seller can still confirm' do
      order.update!(expires_at: 1.minute.ago)
      BetterTogether::Billing::Orders::Expire.call(order)

      described_class.claim(offline, reference: 'paid late')

      expect(offline.reload).to have_attributes(status: 'expired', buyer_reference: 'paid late')
      expect { described_class.receive(offline, by: steward) }.not_to raise_error
    end

    it 'is limited, so it cannot be used to flood the seller' do
      described_class::CLAIM_LIMIT.times { described_class.claim(offline) }

      expect { described_class.claim(offline) }.to raise_error(described_class::TooManyClaims)
    end

    it 'encrypts the reference at rest' do
      described_class.claim(offline, reference: 'my private note')
      raw = BetterTogether::Billing::OfflinePayment.connection.select_value(
        "SELECT buyer_reference FROM better_together_billing_offline_payments WHERE id = '#{offline.id}'"
      )

      expect(raw).not_to include('private')
    end
  end

  describe 'rejecting' do
    it 'fails the payment, cancels the order so what it held is released, and tells the buyer' do
      clear_notices
      deliver_now { described_class.reject(offline, by: steward, reason: 'nothing arrived') }

      expect(offline.reload).to have_attributes(status: 'rejected', rejection_reason: 'nothing arrived')
      expect(offline.payment.reload).to be_failed
      expect(order.reload).to be_cancelled
      expect(kinds_for(buyer)).to include('payment_rejected')
    end

    it 'works whether or not the buyer claimed' do
      described_class.claim(offline)

      expect { described_class.reject(offline, by: steward) }.not_to raise_error
    end

    it 'leaves the order open when another payment has money against it' do
      enable_offline('cash')
      offline.payment.update!(amount_cents: 3500)
      part = BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 1000, idempotency_key: 'part')
      BetterTogether::Billing::Payments::Succeed.call(part)

      described_class.reject(offline, by: steward)

      expect(order.reload).to be_partially_paid
    end
  end

  describe 'a cheque' do
    let(:cheque_order) { place_offline('cheque') }
    let(:cheque) { offline_for(cheque_order) }

    it 'is received, then cleared, and grants access only once it clears by default' do
      described_class.receive(cheque, by: steward)
      expect(cheque.reload).to have_attributes(status: 'received', grant_on: 'cleared')
      expect(cheque_order.reload).to be_awaiting_payment

      described_class.clear(cheque, by: steward)
      expect(cheque.reload.status).to eq('cleared')
      expect(cheque_order.reload).to be_paid
    end

    it 'grants access as soon as it is received when the seller chose that' do
      enable_offline('cheque', grant_on: 'received')
      early = offline_for(place_order(payment_method: 'cheque'))

      described_class.receive(early, by: steward)

      expect(early.reload.order).to be_paid
    end

    it 'reverses what it granted when a cheque that granted on receipt bounces' do
      enable_offline('cheque', grant_on: 'received')
      early = offline_for(place_order(payment_method: 'cheque'))
      described_class.receive(early, by: steward)
      clear_notices

      deliver_now { described_class.bounce(early, by: steward) }

      expect(early.reload.status).to eq('bounced')
      expect(early.order.reload).to be_refunded
      expect(early.payment.reload.refunds.map(&:reason)).to eq(['bounced'])
      expect(kinds_for(buyer)).to include('cheque_bounced')
      expect(kinds_for(buyer)).not_to include('refund_recorded')
    end

    it 'grants nothing and releases the order when a cheque that had not granted bounces' do
      described_class.receive(cheque, by: steward)

      described_class.bounce(cheque, by: steward)

      expect(cheque.reload.status).to eq('bounced')
      expect(cheque.payment.reload).to be_failed
      expect(cheque_order.reload).to be_cancelled
    end

    it 'holds the order open while a received cheque waits to clear' do
      described_class.receive(cheque, by: steward)
      cheque_order.update!(expires_at: 1.minute.ago)

      expect(BetterTogether::Billing::Orders::Expire.call(cheque_order)).to be(false)
      expect { BetterTogether::Billing::Orders::Cancel.call(cheque_order) }
        .to raise_error(BetterTogether::Billing::Orders::Cancel::Refused)
    end

    it 'cannot be cleared before it is received, and cash cannot clear or bounce' do
      expect { described_class.clear(cheque, by: steward) }.to raise_error(described_class::NotAllowed)
      expect { described_class.bounce(cheque, by: steward) }.to raise_error(described_class::NotAllowed)
      expect { described_class.clear(offline, by: steward) }.to raise_error(described_class::NotAllowed)
    end

    it 'tells the buyer when it is received and when it clears' do
      clear_notices
      deliver_now do
        described_class.receive(cheque, by: steward)
        described_class.clear(cheque, by: steward)
      end

      expect(kinds_for(buyer)).to include('cheque_received', 'cheque_cleared')
    end
  end

  describe 'the hold running out or the order being cancelled' do
    it 'expires a waiting payment with its order and logs it' do
      order.update!(expires_at: 1.minute.ago)

      BetterTogether::Billing::Orders::Expire.call(order)

      expect(offline.reload).to have_attributes(status: 'expired')
      expect(offline.expired_at).to be_present
      expect(offline.payment.reload).to be_cancelled
      expect(events_for(offline)).to eq(['cash.payment_expired'])
    end

    it 'cancels a waiting payment with its order' do
      BetterTogether::Billing::Orders::Cancel.call(order)

      expect(offline.reload.status).to eq('cancelled')
      expect(offline.payment.reload).to be_cancelled
    end

    it 'leaves a payment that is already confirmed alone' do
      described_class.receive(offline, by: steward)

      described_class.release(offline, 'expired')

      expect(offline.reload.status).to eq('confirmed')
    end
  end

  describe 'the record of what happened' do
    it 'logs an event per move, naming the actor and never a reference or instruction' do
      described_class.claim(offline, reference: 'secret ref')
      described_class.receive(offline, by: steward, reference: 'another secret')

      events = BetterTogether::Billing::Event.about(offline).order(:created_at)

      expect(events.map(&:event_type)).to eq(%w[cash.payment_claimed cash.payment_confirmed])
      expect(events.map(&:outcome_kind)).to eq(%w[payment_claimed payment_confirmed])
      expect(events.last.payload).to include('actor_id' => steward.id)
      expect(events.map { |event| event.payload.to_s }.join).not_to include('secret', 'Alex')
    end
  end

  describe 'an e-transfer' do
    it 'is confirmed like cash' do
      transfer = offline_for(place_offline('etransfer'))

      described_class.receive(transfer, by: steward)

      expect(transfer.reload.status).to eq('confirmed')
      expect(transfer.order).to be_paid
    end
  end
end
