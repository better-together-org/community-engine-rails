# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::PageView do
  describe 'UTF-8 URL handling in set_page_url' do
    let(:utf8_urls) do
      [
        'https://例え.テスト/ページ', # Japanese IDN with path
        'https://тест.рф/страница', # Cyrillic IDN with path
        'https://example.com/café',    # UTF-8 path
        'https://example.com/页面?参数=值', # Chinese with query params
        'https://bücher.example.com/straße?buch=möglich', # German with query
        'https://пример.испытание/тест?параметр=значение' # Full Cyrillic with query
      ]
    end

    let(:valid_attributes) do
      {
        locale: 'en',
        viewed_at: Time.current
      }
    end

    context 'when handling UTF-8 URLs manually' do
      it 'handles UTF-8 URLs without errors' do
        page_view = described_class.new(valid_attributes)
        # Manually set a UTF-8 URL as if it came from a pageable
        page_view.page_url = 'https://example.com/café'

        expect { page_view.valid? }.not_to raise_error
        expect(page_view.errors[:page_url]).to be_empty
      end
    end

    it 'parses UTF-8 URLs correctly' do
      utf8_urls.each do |url|
        page_view = described_class.new(valid_attributes.merge(page_url: url))

        # Should not add validation errors for UTF-8 URLs
        page_view.valid?
        expect(page_view.errors[:page_url]).to be_empty,
                                               # rubocop:todo Layout/LineLength
                                               "URL #{url} should be valid but got errors: #{page_view.errors.full_messages}"
        # rubocop:enable Layout/LineLength
      end
    end

    it 'handles URL-encoded UTF-8 characters' do
      # Test both raw and encoded versions
      raw_url = 'https://example.com/café'
      encoded_url = 'https://example.com/caf%C3%A9'

      page_view1 = described_class.new(valid_attributes.merge(page_url: raw_url))
      page_view2 = described_class.new(valid_attributes.merge(page_url: encoded_url))

      page_view1.valid?
      page_view2.valid?

      expect(page_view1.errors[:page_url]).to be_empty
      expect(page_view2.errors[:page_url]).to be_empty
    end

    it 'extracts path correctly from UTF-8 URLs' do
      # Test the URI parsing logic directly
      page_view = described_class.new(valid_attributes)

      # Test that our safe_parse_uri method can handle UTF-8
      uri = page_view.send(:safe_parse_uri, 'https://example.com/café?param=value')
      expect(uri).not_to be_nil
      # URI encoding properly converts UTF-8 characters to percent-encoded format
      expect(uri.path).to eq('/caf%C3%A9') # This is correct UTF-8 encoding
      expect(uri.query).to eq('param=value')
    end
  end
end
