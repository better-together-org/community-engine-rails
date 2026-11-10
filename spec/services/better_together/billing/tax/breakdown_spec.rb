# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Tax::Breakdown do
  def line(label, rate, amount, included: false) = Struct.new(:label, :rate, :included, :amount_cents).new(label, rate, included, amount)

  it 'adds up the amounts of lines that are the same tax' do
    groups = described_class.from([line('GST', 0.05, 100), line('GST', 0.05, 25), line('PST', 0.07, 40)])

    expect(groups.map { |g| [g.label, g.amount_cents] }).to eq([['GST', 125], ['PST', 40]])
  end

  it 'keeps a tax inside the price apart from the same tax added on top' do
    groups = described_class.from([line('VAT', 0.2, 10, included: true), line('VAT', 0.2, 5)])

    expect(groups.map(&:included)).to eq([true, false])
  end

  it 'reads a rate as a percentage without trailing zeros' do
    expect(described_class.new(label: 'HST', rate: 0.15, included: false, amount_cents: 1).percent).to eq('15%')
    expect(described_class.new(label: 'QST', rate: 0.09975, included: false, amount_cents: 1).percent).to eq('9.975%')
  end
end
