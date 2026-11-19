# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Orders::Summary do
  include_context 'with orders fixtures'
  include_context 'with quebec tax'

  let(:order) { place_order(tax_address: quebec_address) }
  let(:summary) { described_class.for_order(order) }

  it 'has one row per tax, with its rate, what it applies to and the tax', :aggregate_failures do
    expect(summary.tax_rows.map { |r| [r.label, r.percent, r.base_cents, r.amount_cents] })
      .to eq([['GST', '5%', 4500, 225], ['QST', '9.975%', 4500, 449]])
  end

  it 'adds up: subtotal plus the added tax is the total', :aggregate_failures do
    expect(summary).to have_attributes(subtotal_cents: 4500, taxed?: true, tax_cents: 674, added_tax_cents: 674, total_cents: order.total_cents)
    expect(summary.subtotal_cents + summary.added_tax_cents).to eq(summary.total_cents)
  end

  it 'marks the taxed line' do
    expect(summary.lines.map(&:taxed)).to eq([true])
  end

  it 'names the number of whoever collected each tax' do
    expect(summary.registrations.map { |r| [r.labels, r.number] })
      .to eq([[['GST'], '123456789RT0001'], [['QST'], '1234567890TQ0001']])
  end

  it 'has no tax rows, and no registrations, for an order without tax', :aggregate_failures do
    untaxed = described_class.for_order(place_order(tax_address: { country_iso: 'DE' }))

    expect(untaxed).to have_attributes(taxed?: false, tax_rows: [], registrations: [], total_cents: 4500)
    expect(untaxed.lines.map(&:taxed)).to eq([false])
  end

  describe 'when prices include tax' do
    before { BetterTogether::Billing::TaxRegistration.update_all(prices_include_tax: true) }

    it 'takes the tax out of the price for the base, and adds nothing', :aggregate_failures do
      inclusive = described_class.for_order(place_order(tax_address: quebec_address))

      expect(inclusive.tax_rows).to all(have_attributes(included: true))
      expect(inclusive.added_tax_cents).to eq(0)
      expect(inclusive.total_cents).to eq(4500)
      expect(inclusive.tax_rows.first.base_cents).to eq(4500 - inclusive.tax_cents)
    end
  end

  describe 'a plan about to be bought' do
    it 'reads the same as the order it becomes', :aggregate_failures do
      preview = BetterTogether::Billing::Checkout::TaxPreview.new(platform: host_platform, plan:, address: nil)
      expect(preview.summary).to have_attributes(taxed?: false, total_cents: 4500)
    end
  end
end
