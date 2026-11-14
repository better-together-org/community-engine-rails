# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformThemeConfig do
  describe 'built-in themes' do
    it 'ships five themes with every token, a known font and radius' do
      themes = described_class.themes
      expect(themes.keys).to contain_exactly('neutral', 'warm', 'cool', 'high_contrast', 'dark')
      themes.each_value do |tokens|
        expect(tokens.keys - %w[font radius dark]).to match_array(described_class::COLOR_KEYS)
        expect(tokens['dark'].keys).to match_array(described_class::COLOR_KEYS)
        expect(described_class::FONT_STACKS).to have_key(tokens['font'])
        expect(described_class::RADII).to have_key(tokens['radius'])
      end
    end

    it 'meets the minimum contrast for every pair of every theme (AA for text, 3:1 for the focus accent)' do
      described_class.themes.each do |id, tokens|
        { 'light' => tokens, 'dark' => tokens['dark'] }.each do |mode, set|
          described_class::CONTRAST_PAIRS.each do |fg, bg, minimum|
            ratio = described_class.contrast_ratio(set[fg], set[bg])
            expect(ratio).to be >= minimum, "#{id} (#{mode}): #{fg} on #{bg} is #{ratio}, needs #{minimum}"
          end
        end
      end
    end

    it 'marks which dark text pairs reach AAA' do
      tokens = described_class.themes['high_contrast']['dark']
      aaa = described_class::CONTRAST_PAIRS.select do |fg, bg, min|
        min >= 4.5 && described_class.contrast_ratio(tokens[fg], tokens[bg]) >= 7
      end
      expect(aaa.size).to eq(8)
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

  describe 'dark mode' do
    let(:custom_light) do
      { 'primary' => '#ee722a', 'primary_text' => '#ffffff', 'accent' => '#b8480f', 'accent_dark' => '#8a3a0e',
        'page_bg' => '#fffaf5', 'band' => '#f5f5f5', 'body_text' => '#243542', 'link' => '#243542',
        'navbar_bg' => '#243542', 'navbar_link' => '#ffffff', 'footer_bg' => '#243542', 'footer_link' => '#ffffff' }
    end

    it 'derives a dark set that meets AA for every pair, for the built-in themes and a custom one' do
      sets = described_class.themes.transform_values { |t| t.except('dark', 'font', 'radius') }.merge('custom' => custom_light)
      sets.each do |id, light|
        dark = described_class.derive_dark(light)
        described_class::CONTRAST_PAIRS.each do |fg, bg, minimum|
          ratio = described_class.contrast_ratio(dark[fg], dark[bg])
          expect(ratio).to be >= minimum, "#{id} derived dark: #{fg} on #{bg} is #{ratio}, needs #{minimum}"
        end
      end
    end

    it 'derives only the colours that have a light value and against Bootstrap dark when the page is unset' do
      dark = described_class.derive_dark('link' => '#0b5394', 'body_text' => '#212529')

      expect(dark.keys).to contain_exactly('link', 'body_text')
      expect(described_class.contrast_ratio(dark['link'], described_class::DARK_DEFAULT_PAGE_BG)).to be >= 4.5
    end

    it 'defaults to enabled and auto, and reads the stored mode settings' do
      expect(described_class.new({})).to be_dark_mode_enabled
      expect(described_class.new({}).default_mode).to eq('auto')
      config = described_class.new('dark_mode' => 'disabled', 'default_mode' => 'dark')
      expect(config).not_to be_dark_mode_enabled
      expect(config.default_mode).to eq('dark')
    end

    it 'rejects unknown mode values' do
      expect(described_class.errors_for('dark_mode' => 'maybe', 'default_mode' => 'sepia', 'dark_source' => 'x').size).to eq(3)
    end

    it 'prefers custom dark tokens and fills the rest by derivation' do
      config = described_class.new(custom_light.merge('dark_source' => 'custom', 'dark_page_bg' => '#101010'))

      expect(config.dark_values['page_bg']).to eq('#101010')
      expect(config.dark_values['link']).to be_present
    end

    it 'warns about custom dark pairs below AA' do
      config = described_class.new(custom_light.merge('dark_source' => 'custom', 'dark_body_text' => '#222222', 'dark_page_bg' => '#101010'))

      expect(config.low_contrast_pairs_dark.map { |fg, bg, _| [fg, bg] }).to include(%w[body_text page_bg])
    end

    it 'renders dark custom properties under data-bs-theme and omits them when disabled' do
      css = described_class.new(custom_light).to_css
      expect(css).to include('[data-bs-theme="dark"]', '--bts-page-bg:')

      expect(described_class.new(custom_light.merge('dark_mode' => 'disabled')).to_css).not_to include('data-bs-theme')
    end

    it 'flattens a built-in theme to form values with dark_ tokens' do
      flat = described_class.flat_theme('warm')

      expect(flat).to include('dark_source' => 'custom', 'dark_page_bg' => described_class.themes['warm']['dark']['page_bg'])
      expect(flat).not_to have_key('dark')
    end
  end
end
