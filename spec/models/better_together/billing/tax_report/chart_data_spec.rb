# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::TaxReport::ChartData do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing report data'

  let(:result) do
    BetterTogether::Billing::TaxReport.new(platform: host_platform, from: Time.utc(2026, 1, 1), to: Time.utc(2026, 3, 31, 23, 59, 59),
                                           interval: 'month').call
  end

  before do
    order = paid_order(paid_at: Time.utc(2026, 2, 10))
    line_for(order, cents: 10_000, taxes: [['HST', 0.15, 1500]])
    pay(order)
  end

  it 'gives stacked datasets by period', :aggregate_failures do
    chart = described_class.new(result, 'CAD').revenue

    expect(chart[:labels]).to include('2026-02')
    expect(chart[:datasets].size).to eq(5)
    expect(chart[:datasets].first[:data].sum).to eq(100.0)
  end

  it 'gives tax by rate as labels and values', :aggregate_failures do
    chart = described_class.new(result, 'CAD').tax_by_rate

    expect(chart[:labels].first).to start_with('HST')
    expect(chart[:values]).to eq([15.0])
  end

  it 'is empty for a currency with no activity rather than showing another currency', :aggregate_failures do
    expect(described_class.new(result, 'USD').revenue).to eq(labels: [], datasets: [])
    expect(described_class.new(result, 'USD').tax_by_rate).to eq(labels: [], values: [])
  end

  it 'is empty when there are no sales' do
    empty = BetterTogether::Billing::TaxReport.new(platform: host_platform, from: Time.utc(2020, 1, 1), to: Time.utc(2020, 1, 31)).call

    expect(described_class.new(empty, 'CAD').revenue).to eq(labels: [], datasets: [])
  end
end
