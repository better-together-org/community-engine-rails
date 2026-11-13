# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformContentConfig do
  describe '.sanitize' do
    it 'keeps known keys and locales and drops blanks' do
      result = described_class.sanitize('header_html' => { 'en' => ' <p>Hi</p> ', 'fr' => '', 'xx' => 'no' },
                                        'evil' => { 'en' => 'x' })

      expect(result).to eq('header_html' => { 'en' => '<p>Hi</p>' })
    end
  end

  describe '.errors_for' do
    it 'flags html over the limit and too many or too long headlines' do
      long = 'a' * (described_class::MAX_HEADLINE_LENGTH + 1)
      bad = described_class.errors_for(
        'header_html' => { 'en' => 'a' * (described_class::MAX_HTML_LENGTH + 1) },
        'not_found_headlines' => { 'en' => long, 'fr' => "ok\nfine" }
      )

      expect(bad).to contain_exactly(%w[header_html en], %w[not_found_headlines en])
    end
  end

  describe 'lookups' do
    subject(:config) do
      described_class.new('footer_html' => { 'en' => 'E' },
                          'not_found_headlines' => { 'en' => "One\nTwo\n\n", 'fr' => "Un\nDeux" })
    end

    it 'falls back to the default locale' do
      expect(config.html(:footer_html, :es)).to eq('E')
    end

    it 'returns headlines for the locale, one per non-blank line' do
      expect(config.headlines(:fr)).to eq(%w[Un Deux])
    end

    it 'samples from the set and is nil when empty' do
      expect(config.random_headline(:en)).to be_in(%w[One Two])
      expect(described_class.new({}).random_headline).to be_nil
    end
  end
end
