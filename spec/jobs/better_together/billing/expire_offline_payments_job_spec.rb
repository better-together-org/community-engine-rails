# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ExpireOfflinePaymentsJob do
  include_context 'with offline payment fixtures'

  # An offline payment is held as long as its order, so both lapse together.
  def lapse(order)
    order.update!(expires_at: 1.hour.ago)
    offline_for(order).update_columns(expires_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
    order
  end

  it 'runs on the billing queue' do
    expect(described_class.new.queue_name).to eq(BetterTogether::Billing::ApplicationJob.new.queue_name)
  end

  it 'lets orders whose hold ran out lapse, with their waiting payments, and leaves the rest' do
    lapsed = lapse(place_offline('cash'))
    current = place_offline('cash', buyer: other_buyer)
    paid = place_offline('cash', buyer: steward).tap { |order| transition.receive(offline_for(order), by: other_steward) }

    described_class.perform_now

    expect(lapsed.reload).to be_expired
    expect(offline_for(lapsed).reload.status).to eq('expired')
    expect(offline_for(current).reload.status).to eq('awaiting')
    expect(offline_for(paid).reload.status).to eq('confirmed')
  end

  it 'closes a payment left waiting beside an order that was closed some other way' do
    order = place_offline('cash')
    offline = offline_for(order)
    order.update_columns(status: 'cancelled') # rubocop:disable Rails/SkipsModelValidations
    offline.update_columns(expires_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

    described_class.perform_now

    expect(offline.reload.status).to eq('expired')
  end

  it 'leaves a cheque the seller received but has not seen clear' do
    order = place_offline('cheque')
    transition.receive(offline_for(order), by: steward)
    lapse(order)

    described_class.perform_now

    expect(order.reload).to be_awaiting_payment
    expect(offline_for(order).reload.status).to eq('received')
  end

  it 'covers every platform and survives one bad row' do
    other = create(:better_together_platform)
    foreign_order = create(:better_together_billing_order, :awaiting_payment, platform: other, total_cents: 100, expires_at: 1.hour.ago)
    foreign_payment = create(:better_together_billing_payment, order: foreign_order, platform_id: other.id, processor: 'cash', amount_cents: 100)
    foreign = foreign_order.offline_payments.create!(platform_id: other.id, payment: foreign_payment, processor: 'cash', expires_at: 1.hour.ago)
    mine = lapse(place_offline('cash'))
    allow(BetterTogether::Billing::Orders::Expire).to receive(:call).and_wrap_original do |original, order|
      raise 'boom' if order.id == foreign_order.id

      original.call(order)
    end

    expect { described_class.perform_now }.not_to raise_error
    expect(offline_for(mine).reload.status).to eq('expired')
    expect(foreign.reload.status).to eq('awaiting')
  end
end
