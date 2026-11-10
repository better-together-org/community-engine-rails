# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Orders::Document do
  include_context 'with orders fixtures'
  include_context 'with quebec tax'

  let(:order) { place_order(tax_address: quebec_address) }
  let(:summary) { BetterTogether::Billing::Orders::Summary.for_order(order) }

  def money(cents) = ActionController::Base.helpers.number_to_currency(cents / 100.0, unit: 'US$')

  def pay!(amount = order.total_cents)
    create(:better_together_billing_payment, order:, amount_cents: amount, status: 'succeeded', currency: 'USD', paid_at: Time.current)
    BetterTogether::Billing::Orders::Settle.call(order)
    order.reload
  end

  def cells(rows) = rows.flatten.map { |cell| (cell.is_a?(Hash) ? cell[:content] : cell).to_s.gsub(%r{</?b>}, '') }

  describe 'an unpaid order' do
    it 'is an invoice, a real PDF, named by the order number only', :aggregate_failures do
      document = described_class.new(order)

      expect(document.kind).to eq(:invoice)
      expect(document.to_pdf).to start_with('%PDF')
      expect(document.filename).to eq("invoice-#{order.number}.pdf")
    end

    it 'has the figures the order page shows: the item, one row per tax, the total', :aggregate_failures do
      document = described_class.new(order)
      text = cells(document.sections[:items] + document.sections[:totals])

      expect(text).to include('Taxed', money(4500), money(summary.total_cents))
      expect(text).to include("GST (5%) on #{money(4500)}", money(225), "QST (9.975%) on #{money(4500)}", money(449))
      expect(summary.total_cents).to eq(5174)
    end

    it 'leaves the tax cell empty for a line that is not taxed', :aggregate_failures do
      document = described_class.new(order)
      line = BetterTogether::Billing::Orders::Summary::Line
      allow(document.summary).to receive(:lines).and_return([line.new(description: 'Plan', quantity: 1, amount_cents: 4500, taxed: true),
                                                             line.new(description: 'Produce', quantity: 2, amount_cents: 800, taxed: false)])

      expect(document.sections[:items].drop(1).map { |row| row[1] }).to eq(['Taxed', ''])
    end

    it 'ends with the registration numbers of whoever collected each tax' do
      expect(described_class.new(order).sections[:footer]).to include('GST: 123456789RT0001', 'QST: 1234567890TQ0001')
    end

    it 'has no payment details, only the buyer and the order', :aggregate_failures do
      sections = described_class.new(order).sections
      everything = cells(sections.values_at(:details, :recipient, :items, :totals, :footer)).join(' ')

      expect(sections[:recipient]).to eq([order.buyer.name])
      expect(everything).not_to match(/iban|account number|e-?transfer to|pay to/i)
    end
  end

  describe 'a paid order' do
    before { pay! }

    it 'is a receipt that says when and how it was paid', :aggregate_failures do
      document = described_class.new(order)

      expect(document.kind).to eq(:receipt)
      expect(document.to_pdf).to start_with('%PDF')
      expect(document.filename).to eq("receipt-#{order.number}.pdf")
      expect(cells(document.sections[:details])).to include('Paid', 'Method')
    end

    it 'can still be the invoice' do
      expect(described_class.new(order, kind: :invoice).kind).to eq(:invoice)
    end

    it 'shows what was refunded and what is left paid, once there is a refund', :aggregate_failures do
      BetterTogether::Billing::Refunds::Record.call(payment: order.payments.first, amount_cents: 1000, idempotency_key: 'doc-1',
                                                    status: 'succeeded')
      document = described_class.new(order.reload)
      text = cells(document.sections[:totals])

      expect(document.to_pdf).to start_with('%PDF')
      expect(text).to include('Refunded', "-#{money(1000)}", 'Paid after refunds', money(order.total_cents - 1000))
    end
  end

  describe 'an order with no tax' do
    let(:order) { place_order(tax_address: { country_iso: 'DE' }) }

    it 'keeps three columns and shows no tax rows or numbers', :aggregate_failures do
      sections = described_class.new(order).sections

      expect(sections[:items].first.size).to eq(3)
      expect(cells(sections[:items])).not_to include('Taxed', 'Not taxed')
      expect(sections[:footer].to_s).not_to include('Registration')
    end
  end

  it 'rejects a kind it does not know' do
    expect { described_class.new(order, kind: :quote) }.to raise_error(ArgumentError)
  end

  it 'renders in Ukrainian, Cyrillic included' do
    expect(described_class.new(order, locale: :uk).to_pdf).to start_with('%PDF')
  end
end
