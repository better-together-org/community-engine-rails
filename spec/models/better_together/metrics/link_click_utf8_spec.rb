# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::LinkClick do
  describe 'UTF-8 URL validation' do
    let(:utf8_urls) do
      [
        'https://例え.テスト', # Japanese IDN
        'https://тест.рф', # Cyrillic IDN
        'https://example.com/café', # UTF-8 path
        'https://example.com/页面', # Chinese characters in path
        'https://bücher.example.com/straße', # German umlauts
        'https://пример.испытание/тест' # Full Cyrillic URL
      ]
    end

    let(:valid_attributes) do
      {
        page_url: 'https://example.com/test',
        locale: 'en',
        clicked_at: Time.current,
        internal: false
      }
    end

    it 'accepts UTF-8 encoded URLs' do
      utf8_urls.each do |url|
        link_click = described_class.new(valid_attributes.merge(url: url))
        expect(link_click).to be_valid, "URL #{url} should be valid but got errors: #{link_click.errors.full_messages}"
      end
    end

    it 'accepts UTF-8 encoded page URLs' do
      utf8_urls.each do |page_url|
        link_click = described_class.new(valid_attributes.merge(page_url: page_url, url: 'https://example.com'))
        expect(link_click).to be_valid,
                              "Page URL #{page_url} should be valid but got errors: #{link_click.errors.full_messages}"
      end
    end

    it 'handles URL encoding properly' do
      # Test both encoded and unencoded versions
      raw_url = 'https://example.com/café'
      encoded_url = 'https://example.com/caf%C3%A9'

      link_click1 = described_class.new(valid_attributes.merge(url: raw_url))
      link_click2 = described_class.new(valid_attributes.merge(url: encoded_url))

      expect(link_click1).to be_valid
      expect(link_click2).to be_valid
    end
  end
end
