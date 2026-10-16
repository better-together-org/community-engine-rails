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

  it 'covers every supported plan currency without error' do
    BetterTogether::Billing::Plan::SUPPORTED_CURRENCY_CODES.each do |code|
      expect { described_class.to_major(100, code) }.not_to raise_error
    end
  end

  it 'has no unit when the currency is unknown' do
    expect(described_class.unit(nil)).to eq('')
  end
end
