# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe ColorContrast do
    it 'gives 21:1 for black on white and 1:1 for a colour on itself' do
      expect(described_class.contrast_ratio('#000000', '#ffffff')).to be_within(0.01).of(21)
      expect(described_class.contrast_ratio('#0072B2', '#0072B2')).to eq(1)
    end

    it 'chooses white text on dark colours and dark text on light ones' do
      expect(described_class.text_color_for('#003366')).to eq(described_class::LIGHT)
      expect(described_class.text_color_for('#FFD43B')).to eq(described_class::DARK)
    end
  end
end
