# frozen_string_literal: true

require 'rails_helper'

# Money Community Engine settles itself becomes a Pay charge when it settles, so every payment is a charge to Pay.
RSpec.describe BetterTogether::Billing::LocalSettlement do
  include_context 'with offline payment fixtures'

  def confirmed(method, **) = place_offline(method, **).tap { |order| transition.receive(offline_for(order), by: steward) }

  def settled(order) = order.payments.reload.find(&:succeeded?)

  def refund_of(payment, amount, key, status: 'recorded')
    BetterTogether::Billing::Refunds::Record.call(payment:, amount_cents: amount, idempotency_key: key, status:)
  end

  %w[cash etransfer].each do |method|
    it "records a #{method} payment as a Pay charge on the buyer's local customer when the seller confirms it" do
      order = confirmed(method, **(method == 'etransfer' ? { purchasable: cad_plan } : {}))
      payment = settled(order)

      expect(payment.pay_charge).to be_a(Pay::Local::Charge)
      expect(payment.pay_charge).to have_attributes(amount: payment.amount_cents, currency: payment.currency.downcase,
                                                    payment_method_type: method, platform_id: order.platform_id)
      expect(payment.pay_charge.customer).to have_attributes(owner: buyer, processor: 'local', platform_id: order.platform_id)
      expect(payment.pay_charge.metadata).to include('bt_order_id' => order.id, 'bt_payment_id' => payment.id)
    end
  end

  it 'records a cheque when it grants, not when it is merely received' do
    order = place_offline('cheque')
    cheque = offline_for(order)

    transition.receive(cheque, by: steward)
    expect(cheque.reload.payment.pay_charge).to be_nil

    transition.clear(cheque, by: steward)
    expect(cheque.reload.payment.pay_charge).to be_a(Pay::Local::Charge)
    expect(cheque.payment.pay_charge.payment_method_type).to eq('cheque')
  end

  it 'records nothing for a payment that is still waiting for the seller' do
    order = place_offline('cash')

    expect(order.payments.first.pay_charge).to be_nil
    expect(Pay::Charge.count).to eq(0)
  end

  it 'uses one local customer per buyer and platform, however many payments they make' do
    first = confirmed('cash')
    second = confirmed('cash', buyer: first.buyer)

    customers = [first, second].map { |order| settled(order).pay_charge.customer }.uniq

    expect(customers.size).to eq(1)
    expect(Pay::Customer.where(owner: buyer).count).to eq(1)
  end

  it 'is safe to repeat, and leaves a payment through a processor to Pay and the processor' do
    order = confirmed('cash')
    payment = settled(order)

    expect { described_class.record!(payment) }.not_to change(Pay::Charge, :count)

    remote = place_order(payment_method: 'fake')
    BetterTogether::Billing::Payments::Succeed.call(remote.payments.first, reference: 'ch_1')
    expect(remote.payments.first.reload.pay_charge).to be_nil
    expect(Pay::Charge.count).to eq(1)
  end

  describe 'refunds' do
    let(:order) { confirmed('cash') }
    let(:payment) { settled(order) }

    it 'keep the charge\'s refunded amount equal to what the payment says was given back' do
      refund_of(payment, 1_000, 'one')
      expect(payment.reload.pay_charge.amount_refunded).to eq(1_000)

      refund_of(payment, 500, 'two')
      expect(payment.reload.pay_charge.amount_refunded).to eq(payment.refunded_cents)
      expect(payment.pay_charge.amount_refunded).to eq(1_500)
    end

    it 'follow a refund that fails after being recorded' do
      pending_refund = refund_of(payment, 4_500, 'full', status: 'pending')
      expect(payment.reload.pay_charge).to be_full_refund

      BetterTogether::Billing::Refunds::Resolve.call(pending_refund, status: 'failed')

      expect(payment.reload.pay_charge.amount_refunded).to eq(0)
      expect(payment.refunded_cents).to eq(0)
    end

    it 'follow a bounced cheque that had already granted' do
      enable_offline('cheque', grant_on: 'received')
      bounced = offline_for(place_order(payment_method: 'cheque'))
      transition.receive(bounced, by: steward)

      transition.bounce(bounced, by: steward)

      expect(bounced.payment.reload.pay_charge).to have_attributes(amount_refunded: bounced.payment.amount_cents)
      expect(bounced.payment.reload.refunded_cents).to eq(bounced.payment.pay_charge.amount_refunded)
    end
  end

  it 'gives a payment a charge that can only be on its own platform, one payment per charge' do
    order = confirmed('cash')
    charge = settled(order).pay_charge
    other = settled(confirmed('cash', buyer: other_buyer))

    expect { other.update!(pay_charge: charge) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
