# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::TaxReport do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing report data'

  let(:zone) { ActiveSupport::TimeZone[host_platform.time_zone] }
  let(:from) { zone.local(2026, 1, 1) }
  let(:to) { zone.local(2026, 12, 31).end_of_day }
  let(:owner) { described_class::Owner.all }
  let(:interval) { 'month' }

  def report(**)
    described_class.new(platform: host_platform, from:, to:, owner:, interval:, **).call
  end

  def cad = report.for_currency('CAD')

  describe 'revenue' do
    it 'splits revenue into taxable, non-taxable and exempt, without the tax in the price' do
      order = paid_order(paid_at: zone.local(2026, 3, 10, 12))
      line_for(order, cents: 10_000, taxes: [['GST', 0.05, 500]])
      line_for(order, cents: 2_000, category: create(:better_together_billing_tax_category, platform: host_platform, taxable: false))
      line_for(order, cents: 1_000)
      inclusive = paid_order(paid_at: zone.local(2026, 3, 11, 12), currency: 'CAD')
      line_for(inclusive, cents: 1_150, taxes: [['HST', 0.15, 150]], included: true)

      expect(cad).to have_attributes(sales_count: 2, taxable_cents: 11_000, non_taxable_cents: 2_000, exempt_cents: 1_000,
                                     revenue_cents: 14_000, tax_collected_cents: 650, gross_cents: 14_650)
    end

    it 'counts only orders that were paid' do
      draft = create(:better_together_billing_order, platform: host_platform, currency: 'CAD', status: 'draft')
      line_for(draft, cents: 500)
      cancelled = paid_order(paid_at: nil, status: 'cancelled')
      line_for(cancelled, cents: 700)

      expect(report.summaries).to be_empty
    end

    it 'keeps currencies apart' do
      line_for(paid_order(paid_at: zone.local(2026, 2, 1, 9), currency: 'CAD'), cents: 1_000)
      line_for(paid_order(paid_at: zone.local(2026, 2, 1, 9), currency: 'USD'), cents: 3_000)

      expect(report.summaries.to_h { |s| [s.currency, s.revenue_cents] }).to eq('CAD' => 1_000, 'USD' => 3_000)
    end
  end

  describe 'period edges in the platform time zone' do
    before { host_platform.update!(time_zone: 'America/St_Johns') }

    it 'puts the last minute of a month in that month and the next minute in the next' do
      line_for(paid_order(paid_at: zone.local(2026, 3, 31, 23, 59, 59)), cents: 100)
      line_for(paid_order(paid_at: zone.local(2026, 4, 1, 0, 0, 0)), cents: 200)

      expect(cad.periods.to_h { |p| [p.starts_on.to_s, p.revenue_cents] }).to eq('2026-03-01' => 100, '2026-04-01' => 200)
    end

    it 'groups by quarter, with the quarter edges falling on the first of January, April, July and October' do
      [[3, 31, 23, 59], [4, 1, 0, 0], [6, 30, 23, 59], [7, 1, 0, 0], [12, 31, 23, 59]].each_with_index do |(m, d, h, min), i|
        line_for(paid_order(paid_at: zone.local(2026, m, d, h, min)), cents: 100 * (i + 1))
      end
      grouped = described_class.new(platform: host_platform, from:, to:, interval: 'quarter').call.for_currency('CAD')

      expect(grouped.periods.to_h { |p| [p.starts_on.to_s, p.revenue_cents] })
        .to eq('2026-01-01' => 100, '2026-04-01' => 500, '2026-07-01' => 400, '2026-10-01' => 500)
    end

    it 'groups by year and leaves out what is outside the span' do
      line_for(paid_order(paid_at: zone.local(2025, 12, 31, 23, 59)), cents: 100)
      line_for(paid_order(paid_at: zone.local(2026, 1, 1, 0, 0)), cents: 200)
      line_for(paid_order(paid_at: zone.local(2027, 1, 1, 0, 0)), cents: 400)
      yearly = described_class.new(platform: host_platform, from:, to:, interval: 'year').call.for_currency('CAD')

      expect(yearly.periods.map { |p| [p.starts_on.to_s, p.revenue_cents] }).to eq([['2026-01-01', 200]])
    end
  end

  describe 'tax by rate and label' do
    it 'adds one tax charged on several lines and orders into one row, and keeps different rates apart' do
      first = paid_order(paid_at: zone.local(2026, 5, 1, 9))
      line_for(first, cents: 10_000, taxes: [['GST', 0.05, 500], ['QST', 0.09975, 998]])
      second = paid_order(paid_at: zone.local(2026, 5, 2, 9))
      line_for(second, cents: 2_000, taxes: [['GST', 0.05, 100]])
      line_for(second, cents: 1_000, taxes: [['GST', 0.06, 60]])

      rows = cad.tax_rows.map { |row| [row.label, row.percent, row.collected_cents] }

      expect(rows).to eq([['GST', '5%', 600], ['GST', '6%', 60], ['QST', '9.975%', 998]])
    end
  end

  describe 'refunds' do
    let(:order) { paid_order(paid_at: zone.local(2026, 6, 1, 9)) }
    let!(:payment) do
      line_for(order, cents: 10_000, taxes: [['GST', 0.05, 500], ['QST', 0.09975, 998]])
      pay(order)
    end

    it 'nets the refund and its pro-rated tax, spread over the order taxes' do
      refund_for(payment, amount: 5_749, tax: 749, at: zone.local(2026, 6, 20, 10))

      expect(cad).to have_attributes(refund_count: 1, refunded_cents: 5_749, refunded_tax_cents: 749, refunded_revenue_cents: 5_000,
                                     net_revenue_cents: 5_000, net_tax_cents: 749)
      expect(cad.tax_rows.map { |r| [r.label, r.refunded_cents] }).to eq([['GST', 250], ['QST', 499]])
    end

    it 'counts a refund in the period it was made, not the sale period' do
      refund_for(payment, amount: 1_149, tax: 149, at: zone.local(2026, 8, 5, 10))

      expect(cad.periods.map { |p| [p.starts_on.to_s, p.refunded_cents] }).to eq([['2026-06-01', 0], ['2026-08-01', 1_149]])
    end

    it 'ignores refunds that failed or are still pending' do
      refund_for(payment, amount: 1_149, tax: 149, at: zone.local(2026, 6, 20), status: 'failed')
      refund_for(payment, amount: 1_149, tax: 149, at: zone.local(2026, 6, 21), status: 'pending')

      expect(cad.refund_count).to eq(0)
    end

    it 'shows refunds of earlier sales even when nothing was sold in the span' do
      refund_for(payment, amount: 1_149, tax: 149, at: zone.local(2026, 6, 20))
      later = described_class.new(platform: host_platform, from: zone.local(2026, 6, 15), to: zone.local(2026, 6, 30)).call.for_currency('CAD')

      expect(later).to have_attributes(sales_count: 0, refunded_tax_cents: 149)
    end
  end

  describe 'payment methods' do
    it 'totals what was paid by each way of paying' do
      pay(line_for(paid_order(paid_at: zone.local(2026, 4, 1, 9)), cents: 1_000).order, processor: 'cash')
      pay(line_for(paid_order(paid_at: zone.local(2026, 4, 2, 9)), cents: 2_000).order, processor: 'cash')
      pay(line_for(paid_order(paid_at: zone.local(2026, 4, 3, 9)), cents: 4_000).order, processor: 'cheque')

      expect(cad.payments.map { |p| [p.processor, p.payment_count, p.amount_cents] }).to eq([['cash', 2, 3_000], ['cheque', 1, 4_000]])
    end
  end

  describe 'owners and tenants' do
    let(:seller) { create(:better_together_community) }

    before do
      line_for(paid_order(paid_at: zone.local(2026, 7, 1, 9)), cents: 1_000)
      line_for(paid_order(paid_at: zone.local(2026, 7, 2, 9), seller:), cents: 2_000)
    end

    it 'covers every owner, the platform alone, or one seller' do
      expect(report.for_currency('CAD').revenue_cents).to eq(3_000)
      expect(report(owner: described_class::Owner.platform).for_currency('CAD').revenue_cents).to eq(1_000)
      expect(report(owner: described_class::Owner.for_seller(seller)).for_currency('CAD').revenue_cents).to eq(2_000)
    end

    it 'never reads another platform' do
      other = create(:better_together_platform)
      line_for(paid_order(paid_at: zone.local(2026, 7, 3, 9), platform: other), cents: 9_999)

      expect(report.for_currency('CAD').revenue_cents).to eq(3_000)
      expect(described_class.new(platform: other, from:, to:).call.for_currency('CAD').revenue_cents).to eq(9_999)
    end
  end

  describe described_class::Owner do
    it 'reads only owners that may sell, and falls back to everyone' do
      id = SecureRandom.uuid

      expect(described_class.parse("BetterTogether::Community:#{id}")).to have_attributes(kind: 'seller', seller_id: id)
      expect(described_class.parse("Kernel:#{id}")).to be_all
      expect(described_class.parse('BetterTogether::Community:1; drop')).to be_all
      expect(described_class.parse('platform')).to be_platform
    end
  end
end
