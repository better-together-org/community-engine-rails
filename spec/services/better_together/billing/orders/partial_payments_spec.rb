# frozen_string_literal: true

require 'rails_helper'

# A part-paid order is accepted as it is: it is placed in parts, one part ending does not end the order, it stays
# open, and it is unwound by returning each part.
RSpec.describe 'Part-paid orders' do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'

  let(:billing) { BetterTogether::Billing }
  let(:place_refused) { billing::Orders::Place::Refused }

  def place_in_parts(parts, **attrs)
    place_order(payments: parts, payment_method: nil, **attrs)
  end

  def settle_part(cents)
    payment = billing::Payments::Create.call(order:, processor: 'fake', amount_cents: cents, idempotency_key: SecureRandom.hex(4))
    billing::Payments::Succeed.call(payment)
  end

  def refund(payment, cents) = billing::Refunds::Record.call(payment:, amount_cents: cents, idempotency_key: SecureRandom.hex(4), notify: false)

  def succeeded_cents(order) = order.payments.reload.select(&:succeeded?).sum(&:amount_cents)

  before { enable_offline('cheque', purposes: %w[subscription one_time]) }

  describe 'placing an order with several parts' do
    it 'spends credit, opens cash for an amount, and cheque for the rest' do
      enable_offline('cheque', purposes: %w[subscription one_time])
      give_credit(1000)

      order = place_in_parts([{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash', amount_cents: 1500 },
                              { payment_method: 'cheque' }])

      expect(order.reload).to be_partially_paid
      expect(order.payments.map { |payment| [payment.processor, payment.amount_cents, payment.status] })
        .to contain_exactly(['store_credit', 1000, 'succeeded'], ['cash', 1500, 'pending'], ['cheque', 2000, 'pending'])
    end

    it 'lets credit say "all I can" and the other way take the rest, whatever order they are named in' do
      give_credit(1800)

      order = place_in_parts([{ payment_method: 'cash' }, { payment_method: 'store_credit' }])

      expect(order.payments.find_by(processor: 'store_credit')).to have_attributes(amount_cents: 1800, status: 'succeeded')
      expect(order.payments.find_by(processor: 'cash')).to have_attributes(amount_cents: 2700, status: 'pending')
    end

    it 'places the order paid in full when the parts add up and each is settled' do
      give_credit(4500)

      order = place_in_parts([{ payment_method: 'store_credit' }])

      expect(order.reload).to be_paid
    end

    it 'refuses parts that pass the order, repeat the rest, or name no way, leaving nothing behind' do
      expect { place_in_parts([{ payment_method: 'cash', amount_cents: 5000 }]) }.to raise_error(place_refused, /more than the order/)
      expect { place_in_parts([{ payment_method: 'cash' }, { payment_method: 'cheque' }]) }.to raise_error(place_refused, /only one part/)
      expect { place_in_parts([{ payment_method: '' }]) }.to raise_error(place_refused, /name a way/)
      expect(billing::Order.count).to eq(0)
    end

    it 'refuses the whole order, and holds nothing, when credit cannot be spent' do
      expect { place_in_parts([{ payment_method: 'store_credit', amount_cents: 100 }, { payment_method: 'cash' }]) }
        .to raise_error(place_refused, /credit/)
      expect(billing::Order.count).to eq(0)
      expect(plan.reload.try(:reserved_quantity).to_i).to eq(0)
    end

    it 'holds the order open for the longest hold of the ways chosen and asks the agreements for every way' do
      gate = instance_double(billing::Checkout::AgreementGate, satisfied?: true, agreements: [])
      allow(billing::Checkout::AgreementGate).to receive(:new).and_return(gate)
      give_credit(1000)

      place_in_parts([{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash' }], agreements: false)

      expect(billing::Checkout::AgreementGate).to have_received(:new).with(hash_including(payment_method: %w[store_credit cash]))
    end
  end

  describe 'a renewal method' do
    it 'is stored on the order when it is a method the platform settles itself' do
      order = place_order(payment_method: 'cash', renewal_payment_method: 'store_credit')

      expect(order.renewal_payment_method).to eq('store_credit')
    end

    it 'is refused when it is not' do
      expect { place_order(payment_method: 'cash', renewal_payment_method: 'fake') }.to raise_error(place_refused, /renew/)
    end
  end

  describe 'one part ending' do
    let(:order) do
      give_credit(1000)
      place_in_parts([{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash', amount_cents: 1500 },
                      { payment_method: 'cheque' }]).tap { enable_offline('cheque', purposes: %w[subscription one_time]) }
    end

    it 'does not cancel the order when the seller rejects a part' do
      cash = order.offline_payments.find_by(processor: 'cash')

      transition.reject(cash, by: steward, reason: 'nothing arrived')

      expect(order.reload).to be_partially_paid
      expect(cash.payment.reload).to be_failed
      expect(order.payments.where(status: 'pending').count).to eq(1)
      expect(succeeded_cents(order)).to eq(1000)
    end

    it 'does not cancel the order when a part lapses with the others still in flight' do
      cash = order.offline_payments.find_by(processor: 'cash')

      transition.release(cash, 'expired')
      transition.reject(order.offline_payments.find_by(processor: 'cheque'), by: steward)

      expect(order.reload).to be_partially_paid
      expect(order.reload.balance_cents).to eq(3500)
    end

    it 'does not cancel the order when a received cheque bounces and credit already paid' do
      cheque = order.offline_payments.find_by(processor: 'cheque')
      transition.receive(cheque, by: steward)
      transition.bounce(cheque, by: steward)

      expect(order.reload).to be_partially_paid
      expect(succeeded_cents(order)).to eq(1000)
    end

    it 'still cancels an order whose only payment is rejected' do
      single = place_order(payment_method: 'cash')

      transition.reject(single.offline_payments.first, by: steward)

      expect(single.reload).to be_cancelled
    end

    it 'goes back to awaiting payment when every part paid is returned, and can then be paid another way' do
      credit_payment = order.payments.find_by(processor: 'store_credit')
      billing::Refunds::Record.call(payment: credit_payment, amount_cents: 1000, idempotency_key: 'back', reason: 'requested_by_buyer',
                                    notify: false)

      expect(order.reload).to be_awaiting_payment
      expect(order.net_paid_cents).to eq(0)

      give_credit(500)
      billing::Orders::AddPayment.call(order:, payment_method: 'store_credit', amount_cents: 500, idempotency_key: 'again')
      expect(order.reload).to be_partially_paid
    end
  end

  describe 'Settle, from net money' do
    let(:order) { place_order(payment_method: nil) }

    it 'moves between awaiting payment, part paid and paid as net money changes' do
      first = settle_part(1000)
      expect(order.reload).to be_partially_paid

      refund(first, 400)
      expect(order.reload).to be_partially_paid
      expect(order.net_paid_cents).to eq(600)

      refund(first, 600)
      expect(order.reload).to be_awaiting_payment

      settle_part(4500)
      expect(order.reload).to be_paid
    end

    it 'keeps a paid order that is later refunded as refunded, not as part paid' do
      payment = settle_part(4500)
      refund(payment, 4500)

      expect(order.reload).to be_refunded
    end

    it 'counts a refund against the balance, so the rest to pay is what is really owed' do
      first = settle_part(3000)
      refund(first, 1000)

      expect(order.reload.balance_cents).to eq(2500)
    end
  end

  describe 'a part-paid order that is not completed in time' do
    let(:order) do
      give_credit(1000)
      place_in_parts([{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash' }]).tap do |placed|
        placed.update!(expires_at: 1.hour.ago)
      end
    end

    it 'stays open: the unpaid part ends, the money and the place are kept' do
      expect(billing::Orders::Expire.call(order)).to be_falsey

      expect(order.reload).to be_partially_paid
      expect(order.payments.find_by(processor: 'cash')).to be_cancelled
      expect(order.offline_payments.first).to be_expired
      expect(succeeded_cents(order)).to eq(1000)
    end

    it 'can still be completed afterwards, by the buyer paying the rest or by the seller confirming the late cash' do
      billing::Orders::Expire.call(order)

      late = order.offline_payments.first
      transition.receive(late, by: steward)

      expect(order.reload).to be_paid
      expect(order.payments.where(status: 'succeeded').sum(:amount_cents)).to eq(4500)
    end

    it 'lets the buyer pay the rest another way after it stalled' do
      billing::Orders::Expire.call(order)

      billing::Orders::AddPayment.call(order:, payment_method: 'cheque', idempotency_key: 'rest')

      expect(order.reload.payments.where(status: 'pending').sum(:amount_cents)).to eq(3500)
    end

    it 'still lapses an unpaid order' do
      unpaid = place_order(payment_method: 'cash').tap { |placed| placed.update!(expires_at: 1.hour.ago) }

      expect(billing::Orders::Expire.call(unpaid)).to be(true)
      expect(unpaid.reload).to be_expired
    end
  end

  describe 'cancelling with the money returned' do
    let(:order) do
      give_credit(1000)
      place_in_parts([{ payment_method: 'store_credit', amount_cents: 1000 }, { payment_method: 'cash', amount_cents: 1500 }])
    end

    it 'is refused while money is against it, and lists how each part goes back' do
      expect { billing::Orders::Cancel.call(order) }.to raise_error(billing::Orders::Cancel::Refused, /return what was paid/)
      pending = billing::Orders::ReturnPayments.pending(order).map { |part| [part.payment.processor, part.kind] }
      expect(pending).to eq([['store_credit', :credit]])
    end

    it 'returns credit parts to the original lots, then cancels and releases the place' do
      billing::Orders::ReturnPayments.call(order:, actor: steward)

      expect(order.reload).to be_awaiting_payment
      expect(credit.find_account(platform: host_platform, holder: buyer, currency: 'USD')).to be_consistent
      expect(credit.find_account(platform: host_platform, holder: buyer, currency: 'USD').balance_cents).to eq(1000)

      billing::Orders::Cancel.call(order)

      expect(order.reload).to be_cancelled
      expect(order.payments.where(status: 'pending')).to be_empty
    end

    it 'leaves cash for the seller to hand back and record' do
      cash = order.offline_payments.first
      transition.receive(cash, by: steward)
      billing::Orders::ReturnPayments.call(order:, actor: steward)

      expect(order.reload).to be_partially_paid
      expect(billing::Orders::ReturnPayments.pending(order).map(&:kind)).to eq([:manual])

      billing::Refunds::Record.call(payment: cash.payment, amount_cents: cash.payment.refundable_cents, idempotency_key: 'handed', notify: false)
      billing::Orders::Cancel.call(order.reload)

      expect(order.reload).to be_cancelled
    end

    it 'does the return once however often it is asked' do
      2.times { billing::Orders::ReturnPayments.call(order:, actor: steward) }

      expect(order.payments.find_by(processor: 'store_credit').refunds.count).to eq(1)
    end
  end
end
