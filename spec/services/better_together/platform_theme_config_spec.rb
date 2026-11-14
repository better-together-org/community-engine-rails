# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformThemeConfig do
  describe 'built-in themes' do
    it 'ships five themes with every token, a known font and radius' do
      themes = described_class.themes
      expect(themes.keys).to contain_exactly('neutral', 'warm', 'cool', 'high_contrast', 'dark')
      themes.each_value do |tokens|
        expect(tokens.keys - %w[font radius]).to match_array(described_class::COLOR_KEYS)
        expect(described_class::FONT_STACKS).to have_key(tokens['font'])
        expect(described_class::RADII).to have_key(tokens['radius'])
      end
    end

    it 'meets the minimum contrast for every pair of every theme (AA for text, 3:1 for the focus accent)' do
      described_class.themes.each do |id, tokens|
        described_class::CONTRAST_PAIRS.each do |fg, bg, minimum|
          ratio = described_class.contrast_ratio(tokens[fg], tokens[bg])
          expect(ratio).to be >= minimum, "#{id}: #{fg} on #{bg} is #{ratio}, needs #{minimum}"
        end
      end
    end

    it 'marks which text pairs reach AAA' do
      aaa = described_class.themes.transform_values do |tokens|
        described_class::CONTRAST_PAIRS.select { |fg, bg, min| min >= 4.5 && described_class.contrast_ratio(tokens[fg], tokens[bg]) >= 7 }
                                       .map { |fg, bg, _| "#{fg}/#{bg}" }
      end

      expect(aaa['high_contrast'].size).to eq(8)
      expect(aaa['neutral']).to include('body_text/page_bg', 'primary_text/primary')
    end

    it 'has a translated name and description in every locale' do
      I18n.available_locales.each do |locale|
        described_class.themes.each_key do |id|
          %w[name description].each do |field|
            expect(I18n.t("better_together.platforms.theme.presets.#{id}.#{field}", locale:, default: nil)).to be_present
          end
        end
      end
    end
  end

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

    it 'rejects an unknown preset id' do
      expect(described_class.errors_for('preset' => 'nope', 'font' => 'tahoma').map(&:first)).to eq(['preset'])
    end
  end

  describe '#to_css' do
    it 'is empty when nothing is set' do
      expect(described_class.new({}).to_css).to eq('')
    end

    it 'emits variables and the rules that consume them' do
      css = described_class.new(described_class.themes['warm']).to_css

      expect(css).to include('--bts-primary: #9c3d10;', '--bts-font: Georgia', '.btn-primary', 'footer a')
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

    it 'passes every built-in theme' do
      described_class.themes.each_value do |tokens|
        expect(described_class.new(tokens).low_contrast_pairs).to be_empty
      end
    end
  end
end
