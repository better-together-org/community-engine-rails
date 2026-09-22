# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics do
  describe '.table_name_prefix' do
    it 'returns the expected prefix' do
      expect(described_class.table_name_prefix).to eq('better_together_metrics_')
    end
  end

  describe 'DEFAULT_RESULT_LEVELS' do
    it 'defines five levels' do
      expect(described_class::DEFAULT_RESULT_LEVELS.length).to eq(5)
    end

    it 'includes none, low, medium, high, excellent levels' do
      levels = described_class::DEFAULT_RESULT_LEVELS.map { |l| l[:level] }
      expect(levels).to eq(%i[none low medium high excellent])
    end

    it 'has excellent level with max of Infinity' do
      excellent = described_class::DEFAULT_RESULT_LEVELS.find { |l| l[:level] == :excellent }
      expect(excellent[:max]).to eq(Float::INFINITY)
    end
  end

  describe '.generate_result_levels' do
    it 'returns DEFAULT_RESULT_LEVELS when no data' do
      expect(described_class.generate_result_levels([])).to eq(described_class::DEFAULT_RESULT_LEVELS)
    end

    it 'returns DEFAULT_RESULT_LEVELS when all zeros' do
      expect(described_class.generate_result_levels([0, 0, 0])).to eq(described_class::DEFAULT_RESULT_LEVELS)
    end

    it 'returns five levels with distribution data' do
      result = described_class.generate_result_levels([1, 5, 10, 20, 30, 50])
      expect(result.length).to eq(5)
    end
  end

  describe '.percentile' do
    it 'returns 0 for an empty array' do
      expect(described_class.percentile([], 50)).to eq(0)
    end

    it 'returns the single value for a one-element array' do
      expect(described_class.percentile([42], 50)).to eq(42.0)
    end

    it 'returns the median for the 50th percentile' do
      sorted = [1, 2, 3, 4, 5]
      expect(described_class.percentile(sorted, 50)).to eq(3.0)
    end

    it 'interpolates between values' do
      sorted = [10, 20]
      result = described_class.percentile(sorted, 75)
      expect(result).to be_between(10.0, 20.0)
    end
  end

  describe '.range_label_for' do
    it 'returns "0" for the none level' do
      level = described_class::DEFAULT_RESULT_LEVELS.find { |l| l[:level] == :none }
      expect(described_class.range_label_for(level)).to eq('0')
    end

    it 'returns "N+" for a level with Infinity max' do
      level = { level: :excellent, min: 25, max: Float::INFINITY }
      expect(described_class.range_label_for(level)).to eq('25+')
    end

    it 'returns a range string for bounded levels' do
      level = { level: :low, min: 1, max: 4.99 }
      expect(described_class.range_label_for(level)).to eq('1-4')
    end
  end
end
