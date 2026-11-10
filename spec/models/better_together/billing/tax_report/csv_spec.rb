# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::TaxReport::Csv do
  let(:data) do
    { 'from' => '2026-01-01', 'to' => '2026-01-31', 'interval' => 'month', 'time_zone' => 'UTC',
      'summaries' => [{ 'currency' => 'CAD', 'sales_count' => 1, 'gross_cents' => 11_500, 'taxable_cents' => 10_000, 'non_taxable_cents' => 0,
                        'exempt_cents' => 0, 'refund_count' => 0, 'refunded_cents' => 0, 'refunded_revenue_cents' => 0,
                        'refunded_tax_cents' => 0,
                        'tax_rows' => [{ 'label' => '=HYPERLINK("x")', 'rate' => '0.15', 'included' => false, 'collected_cents' => 1500,
                                         'refunded_cents' => 0 }],
                        'payments' => [{ 'processor' => 'cash', 'payment_count' => 1, 'amount_cents' => 11_500 }],
                        'periods' => [] }] }
  end
  let(:rows) { CSV.parse(described_class.generate(data)) }

  it 'writes amounts as decimals in the currency units' do
    expect(rows).to include(['Gross sales (with tax)', '115.00'])
  end

  it 'never lets a label run as a spreadsheet formula' do
    label = rows.find { |row| row[1] == '15%' }&.first

    expect(label).not_to start_with('=')
  end

  it 'lists payment methods' do
    expect(rows).to include(['cash', '1', '115.00'])
  end
end
