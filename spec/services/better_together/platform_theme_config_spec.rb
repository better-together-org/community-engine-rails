# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformThemeConfig do
  describe '.contrast_ratio' do
    it 'is 21:1 for black on white' do
      expect(described_class.contrast_ratio('#000000', '#ffffff')).to eq(21.0)
    end

    it 'flags white on the Foray orange as below AA (2.97:1)' do
      expect(described_class.contrast_ratio('#ffffff', '#ee722a')).to be_between(2.9, 3.0)
    end

    it 'returns nil for invalid colours' do
      expect(described_class.contrast_ratio('red', '#ffffff')).to be_nil
    end
  end

  describe '.sanitize' do
    it 'keeps known keys, lowercases and drops blanks' do
      result = described_class.sanitize('primary' => ' #ABCDEF ', 'font' => '', 'evil' => 'x')

      expect(result).to eq('primary' => '#abcdef')
    end
  end

  describe '.errors_for' do
    it 'reports bad colours, fonts and radii' do
      bad = described_class.errors_for('primary' => 'javascript:x', 'font' => 'comic', 'radius' => 'large',
                                       'link' => '#123456')

      expect(bad.map(&:first)).to contain_exactly('primary', 'font')
    end
  end

  describe '#to_css' do
    it 'is empty when nothing is set' do
      expect(described_class.new({}).to_css).to eq('')
    end

    it 'emits variables and the rules that consume them' do
      css = described_class.new(described_class::PRESETS['foray']).to_css

      expect(css).to include('--bts-primary: #243542;', '--bts-font: Tahoma', '.btn-primary', 'footer a')
    end

    it 'adds the banner variable when a banner url is given' do
      css = described_class.new('primary' => '#243542').to_css(banner_url: '/b.png')

      expect(css).to include('--bts-header-banner: url("/b.png");')
    end
  end

  describe '#low_contrast_pairs' do
    it 'lists pairs under AA and skips unset ones' do
      pairs = described_class.new('primary' => '#ee722a', 'primary_text' => '#ffffff').low_contrast_pairs

      expect(pairs.map(&:first)).to eq(['primary_text'])
    end

    it 'passes the Foray preset' do
      expect(described_class.new(described_class::PRESETS['foray']).low_contrast_pairs).to be_empty
    end
  end
end
