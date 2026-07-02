# frozen_string_literal: true

require 'rails_helper'

# Comprehensive tests for C3 conversion precision and financial accuracy.
# These tests validate that conversion between Tree Seeds (C3 display amount)
# and millitokens (internal storage) maintains precision without floating-point
# errors, especially for edge cases and accumulation scenarios.
#
# CRITICAL: These tests ensure that the remediation of float conversions
# does not introduce precision loss in financial operations.
#
# See: docs/c3/FLOATING_POINT_ASSESSMENT.md for complete analysis
RSpec.describe BetterTogether::C3::Token do
  let(:scale) { BetterTogether::C3::Token::MILLITOKEN_SCALE }

  describe '.c3_to_millitokens' do
    context 'with valid C3 amounts' do
      it 'converts whole numbers correctly' do
        # 1 Tree Seed = 1000 millitokens
        expect(described_class.c3_to_millitokens(1)).to eq(1_000)
        expect(described_class.c3_to_millitokens(10)).to eq(10_000)
        expect(described_class.c3_to_millitokens(100)).to eq(100_000)
      end

      it 'converts fractional amounts correctly' do
        # 0.1 Tree Seeds = 100 millitokens
        expect(described_class.c3_to_millitokens(0.1)).to eq(100)
        # 0.5 Tree Seeds = 500 millitokens
        expect(described_class.c3_to_millitokens(0.5)).to eq(500)
        # 0.001 Tree Seeds = 1 millitoken (minimum unit)
        expect(described_class.c3_to_millitokens(0.001)).to eq(1)
      end

      it 'converts the minimum unit (0.001 Tree Seeds = 1 millitoken)' do
        result = described_class.c3_to_millitokens('0.001')
        expect(result).to eq(1)
      end

      it 'converts common practical amounts' do
        # Common contribution amounts
        expect(described_class.c3_to_millitokens(1.5)).to eq(1_500)
        expect(described_class.c3_to_millitokens(2.25)).to eq(2_250)
        expect(described_class.c3_to_millitokens(10.75)).to eq(10_750)
      end

      it 'handles string input correctly' do
        # String inputs should be converted accurately via BigDecimal
        expect(described_class.c3_to_millitokens('1')).to eq(1_000)
        expect(described_class.c3_to_millitokens('0.5')).to eq(500)
        expect(described_class.c3_to_millitokens('1.875')).to eq(1_875)
      end

      it 'handles zero' do
        expect(described_class.c3_to_millitokens(0)).to eq(0)
        expect(described_class.c3_to_millitokens('0')).to eq(0)
      end
    end

    context 'with invalid C3 amounts' do
      it 'raises ArgumentError for amounts with more than 4 decimal places' do
        expect { described_class.c3_to_millitokens('0.00001') }
          .to raise_error(ArgumentError, /must have at most 4 decimal places/)
      end

      it 'raises ArgumentError for negative amounts' do
        expect { described_class.c3_to_millitokens(-1) }
          .to raise_error(ArgumentError, /must be non-negative/)
      end

      it 'raises ArgumentError for invalid string format' do
        expect { described_class.c3_to_millitokens('not_a_number') }
          .to raise_error(ArgumentError)
      end
    end
  end

  describe '.millitokens_to_c3' do
    context 'with various millitoken amounts' do
      it 'converts whole millitoken values to C3' do
        expect(described_class.millitokens_to_c3(1_000)).to eq(1.0)
        expect(described_class.millitokens_to_c3(10_000)).to eq(10.0)
        expect(described_class.millitokens_to_c3(100_000)).to eq(100.0)
      end

      it 'converts partial millitokens correctly' do
        expect(described_class.millitokens_to_c3(500)).to eq(0.5)
        expect(described_class.millitokens_to_c3(100)).to eq(0.1)
        expect(described_class.millitokens_to_c3(1)).to eq(0.001)
      end

      it 'rounds results to 4 decimal places' do
        # 1234 millitokens = 1.234 C3 (exact)
        expect(described_class.millitokens_to_c3(1_234)).to eq(1.234)
        # 1567 millitokens = 1.567 C3 (exact)
        expect(described_class.millitokens_to_c3(1_567)).to eq(1.567)
      end

      it 'handles zero' do
        expect(described_class.millitokens_to_c3(0)).to eq(0.0)
      end
    end
  end

  describe '.millitokens_to_c3_decimal' do
    it 'returns a BigDecimal for precise API responses' do
      result = described_class.millitokens_to_c3_decimal(1_000)
      expect(result).to be_a(BigDecimal)
      expect(result).to eq(BigDecimal('1'))
    end

    it 'maintains precision in decimal results' do
      result = described_class.millitokens_to_c3_decimal(1_234)
      expect(result.to_s).to include('1.234')
    end
  end

  describe 'round-trip conversion accuracy' do
    it 'maintains precision for whole numbers' do
      original_c3 = 10
      millitokens = described_class.c3_to_millitokens(original_c3)
      converted_back = described_class.millitokens_to_c3(millitokens)
      expect(converted_back).to eq(original_c3.to_f)
    end

    it 'maintains precision for fractional amounts' do
      original_c3 = 1.5
      millitokens = described_class.c3_to_millitokens(original_c3)
      converted_back = described_class.millitokens_to_c3(millitokens)
      expect(converted_back).to eq(original_c3)
    end

    it 'maintains precision for minimum unit (0.001)' do
      original_c3 = 0.001
      millitokens = described_class.c3_to_millitokens(original_c3)
      converted_back = described_class.millitokens_to_c3(millitokens)
      expect(converted_back).to eq(original_c3)
    end

    it 'maintains precision for decimal amounts with trailing zeros' do
      # 1.2000 should convert and back to 1.2
      original_c3_str = '1.2000'
      millitokens = described_class.c3_to_millitokens(original_c3_str)
      converted_back = described_class.millitokens_to_c3(millitokens)
      expect(converted_back).to eq(1.2)
    end
  end

  describe 'accumulation accuracy' do
    it 'accumulates common contributions without precision loss' do
      # Simulate 10 contributions of 0.3 C3 each
      contributions = Array.new(10, 0.3)
      total_millitokens = contributions.sum { |amount| described_class.c3_to_millitokens(amount) }

      # Total should be exactly 3000 millitokens (10 * 300)
      expect(total_millitokens).to eq(3_000)

      # When converted back to C3, should be exactly 3.0
      total_c3 = described_class.millitokens_to_c3(total_millitokens)
      expect(total_c3).to eq(3.0)
    end

    it 'accumulates fractional amounts correctly' do
      # Simulate accumulation of: 1.25 + 2.75 + 0.5 = 4.5
      amounts = [1.25, 2.75, 0.5]
      total_millitokens = amounts.sum { |amount| described_class.c3_to_millitokens(amount) }

      expect(total_millitokens).to eq(4_500)
      total_c3 = described_class.millitokens_to_c3(total_millitokens)
      expect(total_c3).to eq(4.5)
    end

    it 'handles 100 small accumulations without error' do
      # Accumulate 0.01 C3 one hundred times = 1.0 C3
      total_millitokens = 100.times.sum { described_class.c3_to_millitokens(0.01) }

      expect(total_millitokens).to eq(1_000)
      total_c3 = described_class.millitokens_to_c3(total_millitokens)
      expect(total_c3).to eq(1.0)
    end
  end

  describe 'Token model with safe conversions' do
    it 'sets c3_amount using the safe conversion method' do
      token = described_class.new
      token.c3_amount = 1.5

      # Should store exactly 1500 millitokens
      expect(token.c3_millitokens).to eq(1_500)
    end

    it 'handles string input in c3_amount setter' do
      token = described_class.new
      token.c3_amount = '0.875'

      expect(token.c3_millitokens).to eq(875)
    end

    it 'provides safe getter through c3_amount' do
      token = described_class.new
      token.c3_millitokens = 2_345

      # Should convert back to C3 with proper precision
      expect(token.c3_amount).to eq(2.345)
    end
  end

  describe 'Edge cases and boundary conditions' do
    it 'handles very large amounts correctly' do
      # Test with 1 million Tree Seeds
      large_amount = 1_000_000
      millitokens = described_class.c3_to_millitokens(large_amount)
      expect(millitokens).to eq(1_000_000_000)
    end

    it 'converts the maximum 4-decimal precision value' do
      # 0.9999 is the maximum sub-unit amount
      millitokens = described_class.c3_to_millitokens('0.9999')
      expect(millitokens).to eq(999.9)
    end

    it 'does not lose precision with repeated conversions' do
      # Start with an exact value
      original = 1.2345

      # Convert to millitokens and back multiple times
      millitokens = described_class.c3_to_millitokens(original)
      result1 = described_class.millitokens_to_c3(millitokens)

      # Convert again to millitokens from the result
      millitokens2 = described_class.c3_to_millitokens(result1)
      result2 = described_class.millitokens_to_c3(millitokens2)

      # Should maintain consistency
      expect(result1).to eq(original)
      expect(result2).to eq(original)
      expect(millitokens2).to eq(millitokens)
    end
  end
end
