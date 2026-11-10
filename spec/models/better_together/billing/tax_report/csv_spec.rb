# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::TaxReport::Csv do
  let(:data) do
    { 'from' => '2026-01-01', 'to' => '2026-01-31', 'interval' => 'month', 'basis' => 'paid', 'time_zone' => 'UTC',
      'summaries' => [{ 'currency' => 'CAD', 'sales_count' => 1, 'gross_cents' => 11_500, 'taxable_cents' => 8000,
                        'zero_rated_cents' => 2000, 'non_taxable_cents' => 0,
                        'exempt_cents' => 0, 'refund_count' => 0, 'refunded_cents' => 0, 'refunded_revenue_cents' => 0,
                        'refunded_tax_cents' => 0,
                        'tax_rows' => [{ 'label' => '=HYPERLINK("x")', 'rate' => '0.15', 'included' => false, 'authority' => 'gst_hst',
                                         'collected_by' => 'seller', 'collected_cents' => 1500,
                                         'refunded_cents' => 0 }],
                        'payments' => [{ 'processor' => 'cash', 'payment_count' => 1, 'amount_cents' => 11_500 }],
                        'periods' => [],
                        'authorities' => [{ 'authority' => 'gst_hst', 'collected_cents' => 1500, 'refunded_cents' => 0 }],
                        'regions' => [{ 'region_code' => 'NL', 'sales_count' => 1, 'gross_cents' => 11_500, 'tax_cents' => 1500 }],
                        'registrations' => [{ 'country_iso' => 'CA', 'region_code' => 'NL', 'status' => 'registered',
                                              'collected_by' => 'seller', 'masked_number' => '***********0001' }] }] }
  end
  let(:rows) { CSV.parse(described_class.generate(data)) }

  it 'writes amounts as decimals in the currency units' do
    expect(rows).to include(['Gross sales (with tax)', '115.00'])
  end

  it 'never lets a label run as a spreadsheet formula' do
    label = rows.find { |row| row[1] == '15%' }&.first

    expect(label).not_to start_with('=')
  end

  it 'gives the return lines, the tax owed per administrator, the regions and the masked registrations' do
    expect(rows).to include(['Zero-rated supplies', '20.00'], ['Tax owed: gst_hst', '15.00'], ['NL', '1', '115.00', '15.00'],
                            ['CA', 'NL', 'registered', 'seller', '***********0001'])
  end

  it 'lists payment methods' do
    expect(rows).to include(['cash', '1', '115.00'])
  end
end
