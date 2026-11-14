# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Refunds::Record do
  include_context 'with orders fixtures'

  let(:person) { create(:better_together_person) }
  let(:order) { place_order }
  let(:payment) do
    BetterTogether::Billing::Payments::Succeed.call(
      BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 4500, idempotency_key: 'req')
    )
  end

  def record(**attrs) = described_class.call(payment:, amount_cents: 1000, idempotency_key: 'refund-1', **attrs)

  it 'records money given back, with who recorded it and why, and moves the payment and order' do
    refund = record(reason: 'requested_by_buyer', recorded_by: person)

    expect(refund).to have_attributes(status: 'recorded', amount_cents: 1000, reason: 'requested_by_buyer', recorded_by: person,
                                      platform_id: host_platform.id)
    expect(payment.reload).to be_partially_refunded
    expect(order.reload).to be_partially_refunded
  end

  it 'refunds in full across several refunds' do
    record(amount_cents: 1000, idempotency_key: 'one')
    record(amount_cents: 3500, idempotency_key: 'two')

    expect(payment.reload).to be_refunded
    expect(order.reload).to be_refunded
  end

  it 'finds the refund it already made when the request is repeated' do
    first = record

    expect { expect(record).to eq(first) }.not_to change(BetterTogether::Billing::Refund, :count)
  end

  it 'refuses more than is left to refund' do
    record(amount_cents: 4000, idempotency_key: 'one')

    expect { record(amount_cents: 1000, idempotency_key: 'two') }.to raise_error(described_class::Refused, /refunded/)
  end

  it 'records a processor refund as succeeded, with its reference' do
    refund = record(status: 'succeeded', processor_reference: 're_1')

    expect(refund).to have_attributes(status: 'succeeded', processor_reference: 're_1')
  end

  describe 'the tax inside a refund' do
    let(:order) { place_order(tax_address: { country_iso: 'CA', region_code: 'NL' }) }
    let(:payment) do
      BetterTogether::Billing::Payments::Succeed.call(
        BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: order.total_cents, idempotency_key: 'req')
      )
    end

    before do
      create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
      zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'NL')
      create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'HST', rate: 0.15)
    end

    it 'is the refund\'s share of the order\'s tax, split from the net', :aggregate_failures do
      expect(order).to have_attributes(total_cents: 5175, tax_cents: 675)

      refund = record(amount_cents: 1035)

      expect(refund).to have_attributes(tax_cents: 135, net_cents: 900)
    end

    it 'adds up to the order\'s tax to the cent when refunded in pieces' do
      refunds = [1000, 1000, 3175].each_with_index.map { |cents, index| record(amount_cents: cents, idempotency_key: "piece-#{index}") }

      expect(refunds.sum(&:tax_cents)).to eq(675)
      expect(refunds.last.tax_cents).to eq(675 - refunds.first(2).sum(&:tax_cents))
    end

    it 'is only a share when a part-paid order is refunded what it received', :aggregate_failures do
      part = BetterTogether::Billing::Payments::Succeed.call(
        BetterTogether::Billing::Payments::Create.call(order:, processor: 'fake', amount_cents: 1000, idempotency_key: 'part')
      )

      refund = described_class.call(payment: part, amount_cents: 1000, idempotency_key: 'all-of-it')

      expect(order.reload.paid_cents).to be < order.total_cents
      expect(refund.tax_cents).to eq(130) # 675 * 1000 / 5175, not all 675
    end

    it 'is nothing for an order with no tax' do
      plain = place_order(tax_address: { country_iso: 'GB' })
      created = BetterTogether::Billing::Payments::Create.call(order: plain, processor: 'fake', amount_cents: plain.total_cents,
                                                               idempotency_key: 'plain-req')
      untaxed = BetterTogether::Billing::Payments::Succeed.call(created)

      expect(described_class.call(payment: untaxed, amount_cents: 500, idempotency_key: 'plain').tax_cents).to eq(0)
    end
  end
end
