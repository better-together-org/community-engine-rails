# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Currency do
  it 'treats JPY and KRW as zero-decimal and the rest as two-decimal' do
    expect(described_class.exponent('JPY')).to eq(0)
    expect(described_class.exponent('krw')).to eq(0)
    expect(described_class.exponent('USD')).to eq(2)
  end

  it 'converts minor to major units by exponent' do
    expect(described_class.to_major(4_500, 'USD')).to eq(45.0)
    expect(described_class.to_major(1_000, 'JPY')).to eq(1_000.0)
  end

  it 'converts what a person typed to whole minor units, and refuses what is not a plain amount' do
    expect(described_class.to_minor('12.50', 'USD')).to eq(1_250)
    expect(described_class.to_minor(' 7 ', 'USD')).to eq(700)
    expect(described_class.to_minor('1000', 'JPY')).to eq(1_000)
    expect(described_class.to_minor('0.005', 'USD')).to eq(1)
    ['', nil, 'lots', '-5', '1,000', '1e3', '12.5.0'].each { |text| expect(described_class.to_minor(text, 'USD')).to be_nil }
  end

  describe '.parse_major' do
    it 'converts a typed price for the currency, with a decimal point or comma' do
      expect(described_class.parse_major('45', 'USD')).to eq([4_500, nil])
      expect(described_class.parse_major('45.50', 'USD')).to eq([4_550, nil])
      expect(described_class.parse_major('45,50', 'USD')).to eq([4_550, nil])
      expect(described_class.parse_major('4500', 'JPY')).to eq([4_500, nil])
      expect(described_class.parse_major('4500.0', 'JPY')).to eq([4_500, nil])
    end

    it 'says why a price cannot be used' do
      expect(described_class.parse_major('  ', 'USD')).to eq([nil, :blank])
      expect(described_class.parse_major('1,000.00', 'USD')).to eq([nil, :not_an_amount])
      expect(described_class.parse_major('-1', 'USD')).to eq([nil, :not_an_amount])
      expect(described_class.parse_major('1.005', 'USD')).to eq([nil, :too_precise])
      expect(described_class.parse_major('1.5', 'JPY')).to eq([nil, :too_precise])
      expect(described_class.parse_major('1000000000', 'USD')).to eq([nil, :too_large])
    end
  end

  it 'shows a stored price the way it is typed' do
    expect(described_class.to_input(12_345, 'USD')).to eq('123.45')
    expect(described_class.to_input(500, 'JPY')).to eq('500')
  end

  it 'covers every supported plan currency without error' do
    BetterTogether::Billing::Plan::SUPPORTED_CURRENCY_CODES.each do |code|
      expect { described_class.to_major(100, code) }.not_to raise_error
    end
  end

  it 'has no unit when the currency is unknown' do
    expect(described_class.unit(nil)).to eq('')
  end
end
