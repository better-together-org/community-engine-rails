# frozen_string_literal: true

require 'rails_helper'

# Paying an order from store credit, through the way every order is placed.
RSpec.describe BetterTogether::Billing::Credit::PayOrder do # rubocop:disable RSpec/SpecFilePathFormat
  include_context 'with store credit fixtures'

  let(:refused) { BetterTogether::Billing::Orders::Place::Refused }

  context 'with enough credit' do
    before { grant_credit(6000) }

    it 'pays the order whole, at once, from the credit' do
      order = place_with_credit

      expect(order.reload).to be_paid
      payment = order.payments.sole
      expect(payment).to have_attributes(processor: 'store_credit', status: 'succeeded', amount_cents: 4500)
      expect(account_of.reload.balance_cents).to eq(1500)
      expect(account_of.entries.spends.sole).to have_attributes(source: payment, amount_cents: -4500)
      expect(account_of).to be_consistent
    end

    it 'records the payment as a charge Pay can see, like every other settled payment' do
      payment = place_with_credit.payments.sole

      expect(payment.pay_charge).to be_a(Pay::Local::Charge)
      expect(payment.pay_charge).to have_attributes(amount: 4500, amount_refunded: nil)
    end

    it 'opens no offline payment, because there is no seller to confirm anything' do
      order = place_with_credit

      expect(order.offline_payments).to be_empty
    end

    it 'spends the soonest-expiring credit first' do
      soon = grant_credit(5000, expires_at: 2.days.from_now)

      place_with_credit

      expect(soon.reload.remaining_cents).to eq(500)
    end

    it 'tells the buyer their order is paid' do
      receipts = BetterTogether::Billing::NotificationReceipt.where(kind: 'order_paid', recipient: buyer)

      expect { place_with_credit }.to change(receipts, :count).by(1)
    end

    it 'refuses credit kept for a different kind of purchase' do
      other = create(:better_together_person)
      grant_credit(9000, holder: other, purposes: %w[ticket])

      expect { place_with_credit(buyer: other) }.to raise_error(refused, /not enough credit/)
    end
  end

  context 'without enough credit' do
    it 'refuses and leaves nothing behind: no order, no hold, no spend' do
      grant_credit(4499)

      expect { place_with_credit }.to raise_error(refused, /credit/)
        .and(not_change(BetterTogether::Billing::Order, :count))
        .and(not_change(BetterTogether::Billing::CreditEntry, :count))
      expect(account_of.balance_cents).to eq(4499)
    end

    it 'refuses a buyer who has never had credit' do
      expect { place_with_credit }.to raise_error(refused, /credit/)
      expect(account_of).to be_nil
    end

    it 'does not spend credit in another currency' do
      grant_credit(9000, currency: 'CAD')

      expect { place_with_credit }.to raise_error(refused)
    end

    it 'leaves the order unplaced if the credit is gone by the time it is spent' do
      grant_credit(6000)
      allow(BetterTogether::Billing::Credit::Spend).to receive(:call)
        .and_raise(BetterTogether::Billing::Credit::Refused, 'there is not enough credit')

      expect { place_with_credit }.to raise_error(refused, /not enough credit/).and(not_change(BetterTogether::Billing::Order, :count))
    end
  end

  it 'works only when a steward has switched store credit on' do
    grant_credit(6000)
    host_platform.billing_processor_settings.find_by!(processor: 'store_credit').update!(enabled: false)

    expect { place_with_credit }.to raise_error(refused, /not available/)
  end

  it 'works only for the kinds of purchase it is allowed for' do
    grant_credit(6000)
    host_platform.billing_processor_settings.find_by!(processor: 'store_credit').update!(purposes: %w[ticket])

    expect { place_with_credit }.to raise_error(refused, /not available/)
  end

  it 'pays only for what the platform sells, not for a seller' do
    grant_credit(6000)
    BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
    seller = create(:better_together_community)
    seller_plan = create(:better_together_billing_plan, seller:)

    expect { place_with_credit(seller:, lines: [{ purchasable: seller_plan }]) }.to raise_error(refused, /only for what the platform sells/)
  end

  it 'opens no payment for an order that costs nothing, and leaves the credit alone' do
    free = create(:better_together_billing_plan, amount_cents: 0, currency: 'USD')
    grant_credit(100)

    order = place_with_credit(lines: [{ purchasable: free }])

    expect(order).to be_paid
    expect(order.payments).to be_empty
    expect(account_of.reload.balance_cents).to eq(100)
  end
end
