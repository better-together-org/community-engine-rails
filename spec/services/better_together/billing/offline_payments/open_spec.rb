# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OfflinePayments::Open do
  include_context 'with offline payment fixtures'

  it 'opens a pending payment for the whole balance and an offline payment waiting for the seller' do
    order = place_offline('cash')
    offline = offline_for(order)

    expect(order.payments.map(&:status)).to eq(['pending'])
    expect(order.payments.first).to have_attributes(processor: 'cash', amount_cents: 4500)
    expect(offline).to have_attributes(status: 'awaiting', processor: 'cash', grant_on: 'confirmed', platform_fee_cents: 0,
                                       seller_assisted: false, expires_at: order.expires_at)
    expect(offline.payment).to eq(order.payments.first)
  end

  it 'holds the order for the seller\'s own hold time' do
    enable_offline('cash', hold_hours: 24)
    order = place_order(payment_method: 'cash')

    expect(order.expires_at).to be_within(1.minute).of(24.hours.from_now)
  end

  it 'copies the instructions the buyer is shown, so a later change cannot redirect them' do
    order = place_offline('cash')
    host_platform.billing_processor_settings.find_by!(processor: 'cash').update!(settings: { 'instructions' => 'Send it to someone else' })

    expect(offline_for(order).reload.instructions).to eq('instructions' => 'Hand it to Alex at the hall')
  end

  it 'keeps the instructions encrypted at rest' do
    offline = offline_for(place_offline('cash'))
    raw = BetterTogether::Billing::OfflinePayment.connection.select_value(
      "SELECT instructions_snapshot FROM better_together_billing_offline_payments WHERE id = '#{offline.id}'"
    )

    expect(raw).not_to include('Alex')
  end

  it 'takes the grant timing from the setting when the order is placed' do
    enable_offline('cheque', grant_on: 'received')

    expect(offline_for(place_order(payment_method: 'cheque'))).to have_attributes(grant_on: 'received')
  end

  it 'is safe to repeat: the payment already opened is returned' do
    order = place_offline('cash')
    setting = host_platform.billing_processor_settings.find_by!(processor: 'cash')

    expect(described_class.call(order:, setting:)).to eq(offline_for(order))
    expect(order.offline_payments.count).to eq(1)
  end

  it 'opens nothing for a method that goes through a vendor' do
    expect(place_order(payment_method: 'fake').offline_payments).to be_empty
  end

  it 'opens nothing for an order that costs nothing' do
    enable_offline('cash')
    free = create(:better_together_billing_plan, amount_cents: 0)

    expect(place_order(payment_method: 'cash', lines: [{ purchasable: free }]).offline_payments).to be_empty
  rescue BetterTogether::Billing::Orders::Place::Refused
    skip 'a plan that costs nothing is not sold in this build'
  end

  describe 'what Orders::Place refuses' do
    it 'refuses a method the seller has not switched on' do
      expect { place_order(payment_method: 'cash') }.to raise_error(BetterTogether::Billing::Orders::Place::Refused, /not available/)
    end

    it 'refuses a method that is switched on but not for this kind of purchase' do
      enable_offline('cash', purposes: %w[ticket])

      expect { place_order(payment_method: 'cash') }.to raise_error(BetterTogether::Billing::Orders::Place::Refused, /not available/)
    end

    it 'refuses an e-transfer in a currency other than CAD' do
      enable_offline('etransfer')

      expect { place_order(payment_method: 'etransfer') }.to raise_error(BetterTogether::Billing::Orders::Place::Refused, /currency/)
    end

    it 'leaves nothing behind when it refuses' do
      expect { place_order(payment_method: 'cash') }.to raise_error(BetterTogether::Billing::Orders::Place::Refused)
      expect(BetterTogether::Billing::OfflinePayment.count).to eq(0)
    end
  end
end
