# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SafeClassResolver, type: :service do
  describe '.resolve' do
    it 'returns the constant when the name is in the allow-list' do
      result = described_class.resolve('BetterTogether::Page', allowed: ['BetterTogether::Page'])
      expect(result).to eq(BetterTogether::Page)
    end

    it 'returns nil when the name is not in the allow-list' do
      result = described_class.resolve('BetterTogether::Page', allowed: ['BetterTogether::Post'])
      expect(result).to be_nil
    end

    it 'returns nil when the allow-list is empty' do
      result = described_class.resolve('BetterTogether::Page', allowed: [])
      expect(result).to be_nil
    end

    it 'returns nil for a nil name' do
      result = described_class.resolve(nil, allowed: ['BetterTogether::Page'])
      expect(result).to be_nil
    end

    it 'strips a leading :: before matching' do
      result = described_class.resolve('::BetterTogether::Page', allowed: ['BetterTogether::Page'])
      expect(result).to eq(BetterTogether::Page)
    end

    it 'returns nil when the class name is allowed but does not exist' do
      result = described_class.resolve('BetterTogether::NonExistentClass', allowed: ['BetterTogether::NonExistentClass'])
      expect(result).to be_nil
    end

    it 'resolves unnamespaced constants that are in the allow-list' do
      result = described_class.resolve('String', allowed: %w[String])
      expect(result).to eq(String)
    end
  end

  describe '.resolve!' do
    it 'returns the constant when in the allow-list' do
      result = described_class.resolve!('BetterTogether::Post', allowed: ['BetterTogether::Post'])
      expect(result).to eq(BetterTogether::Post)
    end

    it 'raises ArgumentError when the name is not in the allow-list' do
      expect do
        described_class.resolve!('BetterTogether::Page', allowed: [])
      end.to raise_error(ArgumentError, /BetterTogether::Page/)
    end

    it 'raises a custom error class when specified' do
      custom_error = Class.new(StandardError)
      expect do
        described_class.resolve!('BetterTogether::Page', allowed: [], error_class: custom_error)
      end.to raise_error(custom_error)
    end
  end
end
