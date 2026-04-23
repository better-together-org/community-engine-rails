# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::C3Helper do
  let(:scale) { BetterTogether::C3::Token::MILLITOKEN_SCALE }

  describe '#tree_seeds_display' do
    it 'displays whole numbers without decimals' do
      expect(helper.tree_seeds_display(scale)).to eq('1 Tree Seed 🌱')
    end

    it 'uses singular "Tree Seed" for exactly 1 C3' do
      expect(helper.tree_seeds_display(scale)).to include('Tree Seed 🌱')
      expect(helper.tree_seeds_display(scale)).not_to include('Tree Seeds')
    end

    it 'uses plural "Tree Seeds" for amounts other than 1 C3' do
      expect(helper.tree_seeds_display(0)).to include('Tree Seeds')
      expect(helper.tree_seeds_display(2 * scale)).to include('Tree Seeds')
    end

    it 'formats fractional amounts without trailing zeros' do
      # 5000 millitokens = 0.5 C3
      result = helper.tree_seeds_display(5_000)
      expect(result).to eq('0.5 Tree Seeds 🌱')
    end

    it 'formats large amounts as integers' do
      result = helper.tree_seeds_display(100 * scale)
      expect(result).to eq('100 Tree Seeds 🌱')
    end

    it 'omits emoji when include_emoji: false' do
      result = helper.tree_seeds_display(scale, include_emoji: false)
      expect(result).not_to include('🌱')
      expect(result).to include('Tree Seed')
    end

    it 'handles zero gracefully' do
      expect(helper.tree_seeds_display(0)).to eq('0 Tree Seeds 🌱')
    end

    it 'handles nil input as zero' do
      expect(helper.tree_seeds_display(nil)).to eq('0 Tree Seeds 🌱')
    end
  end
end
