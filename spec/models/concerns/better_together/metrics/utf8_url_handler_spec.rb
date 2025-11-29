# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::Utf8UrlHandler do
  # Create a dummy class to test the concern
  let(:test_class) do
    Class.new do
      include BetterTogether::Metrics::Utf8UrlHandler

      # Make private methods public for testing
      public :safe_parse_uri, :encode_utf8_url, :encode_utf8_component,
             :encode_host_component, :valid_utf8_url?
    end
  end

  let(:handler) { test_class.new }

  describe '#safe_parse_uri' do
    context 'with valid ASCII URLs' do
      it 'parses simple HTTP URLs' do
        url = 'http://example.com'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
        expect(uri.scheme).to eq('http')
        expect(uri.host).to eq('example.com')
      end

      it 'parses HTTPS URLs with paths and queries' do
        url = 'https://example.com/path?param=value'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
        expect(uri.scheme).to eq('https')
        expect(uri.host).to eq('example.com')
        expect(uri.path).to eq('/path')
        expect(uri.query).to eq('param=value')
      end
    end

    context 'with UTF-8 URLs' do
      it 'parses UTF-8 URLs with spaces (Ukrainian example)' do
        url = 'https://newcomernavigatornl.ca/uk/попереднє прибуття'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
        expect(uri.scheme).to eq('https')
        expect(uri.host).to eq('newcomernavigatornl.ca')
      end

      it 'parses Japanese URLs' do
        url = 'https://例え.テスト/ページ'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
      end

      it 'parses Cyrillic URLs' do
        url = 'https://тест.рф/страница'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
      end

      it 'parses URLs with accented characters' do
        url = 'https://example.com/café'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
      end

      it 'parses Chinese URLs with query parameters' do
        url = 'https://example.com/页面?参数=值'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
      end

      it 'parses German URLs with special characters' do
        url = 'https://bücher.example.com/straße?buch=möglich'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
      end

      it 'parses Arabic URLs' do
        url = 'https://example.com/صفحة'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
      end

      it 'parses Hebrew URLs' do
        url = 'https://example.com/דף'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
      end

      it 'parses Thai URLs' do
        url = 'https://example.com/หน้า'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
      end

      it 'parses URLs with emoji' do
        url = 'https://example.com/page🎉'
        uri = handler.safe_parse_uri(url)
        expect(uri).not_to be_nil
      end
    end

    context 'with invalid URLs' do
      it 'returns nil for blank URLs' do
        expect(handler.safe_parse_uri('')).to be_nil
        expect(handler.safe_parse_uri(nil)).to be_nil
        expect(handler.safe_parse_uri('  ')).to be_nil
      end

      it 'returns nil for malformed URLs' do
        # NOTE: URI.parse is quite permissive, so we test actual malformed cases
        expect(handler.safe_parse_uri('://missing-scheme')).to be_nil
        expect(handler.safe_parse_uri('http:// invalid spaces')).to be_nil
      end
    end
  end

  describe '#encode_utf8_component' do
    it 'encodes spaces correctly' do
      result = handler.encode_utf8_component('hello world')
      expect(result).to eq('hello%20world')
    end

    it 'encodes Ukrainian characters with spaces' do
      result = handler.encode_utf8_component('попереднє прибуття')
      expect(result).to include('%20') # space should be encoded
      expect(result).to include('%D0%BF') # 'п' should be encoded
    end

    it 'encodes various UTF-8 characters' do
      test_cases = {
        'café' => 'caf%C3%A9',
        'ページ' => '%E3%83%9A%E3%83%BC%E3%82%B8',
        'страница' => '%D1%81%D1%82%D1%80%D0%B0%D0%BD%D0%B8%D1%86%D0%B0',
        'صفحة' => '%D8%B5%D9%81%D8%AD%D8%A9',
        'דף' => '%D7%93%D7%A3',
        'หน้า' => '%E0%B8%AB%E0%B8%99%E0%B9%89%E0%B8%B2'
      }

      test_cases.each do |input, expected|
        result = handler.encode_utf8_component(input)
        expect(result).to eq(expected), "Expected '#{input}' to encode as '#{expected}', got '#{result}'"
      end
    end

    it 'leaves ASCII characters unchanged' do
      ascii_text = 'hello-world_123'
      result = handler.encode_utf8_component(ascii_text)
      expect(result).to eq(ascii_text)
    end

    it 'handles mixed ASCII and UTF-8' do
      result = handler.encode_utf8_component('hello café world')
      expect(result).to eq('hello%20caf%C3%A9%20world')
    end

    it 'handles empty and nil inputs' do
      expect(handler.encode_utf8_component('')).to eq('')
      expect(handler.encode_utf8_component(nil)).to eq('')
      expect(handler.encode_utf8_component('   ')).to eq('%20%20%20')
    end
  end

  describe '#encode_utf8_url' do
    it 'encodes the Ukrainian URL correctly' do
      url = 'https://newcomernavigatornl.ca/uk/попереднє прибуття'
      result = handler.encode_utf8_url(url)
      expect(result).to start_with('https://newcomernavigatornl.ca/uk/')
      expect(result).to include('%20') # space should be encoded
      expect(result).to include('%D0%BF') # Cyrillic characters should be encoded
    end

    it 'preserves protocol and domain' do
      url = 'https://example.com/café world'
      result = handler.encode_utf8_url(url)
      expect(result).to start_with('https://example.com/')
      expect(result).to include('caf%C3%A9%20world')
    end

    it 'handles URLs without protocols' do
      url = 'example.com/café'
      result = handler.encode_utf8_url(url)
      expect(result).to eq('example.com/caf%C3%A9')
    end

    it 'handles complex URLs with query parameters' do
      url = 'https://example.com/页面?参数=值 test'
      result = handler.encode_utf8_url(url)
      expect(result).to start_with('https://example.com/')
      expect(result).to include('%20') # space in query value should be encoded
    end

    it 'handles international domain names' do
      url = 'https://тест.рф/страница'
      result = handler.encode_utf8_url(url)
      expect(result).not_to be_nil
      # IDN domains should be handled
    end

    it 'leaves valid ASCII URLs unchanged' do
      url = 'https://example.com/path?param=value'
      result = handler.encode_utf8_url(url)
      expect(result).to eq(url)
    end
  end

  describe '#encode_host_component' do
    it 'handles international domain names' do
      host = 'тест.рф'
      result = handler.encode_host_component(host)
      expect(result).not_to be_nil
      # Should encode non-ASCII characters in domain
    end

    it 'handles host with path' do
      host_path = 'example.com/café'
      result = handler.encode_host_component(host_path)
      expect(result).to eq('example.com/caf%C3%A9')
    end

    it 'leaves ASCII domains unchanged' do
      host = 'example.com'
      result = handler.encode_host_component(host)
      expect(result).to eq(host)
    end
  end

  describe '#valid_utf8_url?' do
    context 'with valid URLs' do
      let(:valid_urls) do
        [
          'http://example.com',
          'https://example.com/path',
          'https://newcomernavigatornl.ca/uk/попереднє прибуття',
          'https://example.com/café',
          'https://例え.テスト/ページ',
          'https://тест.рф/страница',
          'tel:+1234567890',
          'mailto:user@example.com'
        ]
      end

      it 'returns true for valid URLs' do
        valid_urls.each do |url|
          expect(handler.valid_utf8_url?(url)).to be(true), "Expected '#{url}' to be valid"
        end
      end
    end

    context 'with invalid URLs' do
      let(:invalid_urls) do
        [
          '',
          nil,
          'not-a-url',
          'ftp://example.com', # not in allowed schemes
          'javascript:alert(1)', # not in allowed schemes
          '://missing-scheme'
        ]
      end

      it 'returns false for invalid URLs' do
        invalid_urls.each do |url|
          expect(handler.valid_utf8_url?(url)).to be(false), "Expected '#{url}' to be invalid"
        end
      end
    end

    it 'allows specific schemes only' do
      valid_scheme_urls = {
        'http' => 'http://example.com',
        'https' => 'https://example.com',
        'tel' => 'tel:+1234567890',
        'mailto' => 'mailto:user@example.com'
      }

      valid_scheme_urls.each do |scheme, url|
        expect(handler.valid_utf8_url?(url)).to be(true), "Expected #{scheme} URL '#{url}' to be valid"
      end

      disallowed_schemes = %w[ftp javascript data file]
      disallowed_schemes.each do |scheme|
        url = "#{scheme}://example.com"
        expect(handler.valid_utf8_url?(url)).to be(false), "Expected #{scheme} URL to be invalid"
      end
    end
  end

  describe 'integration tests with real-world URLs' do
    let(:real_world_utf8_urls) do
      [
        'https://newcomernavigatornl.ca/uk/попереднє прибуття', # Ukrainian with space
        'https://ru.wikipedia.org/wiki/Главная_страница', # Russian with underscore
        'https://ja.wikipedia.org/wiki/メインページ', # Japanese
        'https://zh.wikipedia.org/wiki/首页', # Chinese
        'https://ar.wikipedia.org/wiki/الصفحة_الرئيسية', # Arabic with underscore
        'https://he.wikipedia.org/wiki/עמוד_ראשי', # Hebrew with underscore
        'https://th.wikipedia.org/wiki/หน้าหลัก', # Thai
        'https://example.com/path with spaces/file.html', # English with spaces
        'https://café.example.com/menü?schön=wahr', # German IDN with accents
        'https://новости.укр/статья номер один' # Cyrillic IDN with spaces
      ]
    end

    it 'handles all real-world UTF-8 URLs without errors' do
      real_world_utf8_urls.each do |url|
        expect { handler.safe_parse_uri(url) }.not_to raise_error
        expect { handler.encode_utf8_url(url) }.not_to raise_error
        expect { handler.valid_utf8_url?(url) }.not_to raise_error

        # The URL should be parseable after encoding
        encoded = handler.encode_utf8_url(url)
        expect { URI.parse(encoded) }.not_to raise_error
      end
    end

    it 'produces valid encoded URLs that can be parsed by Ruby URI' do
      real_world_utf8_urls.each do |url|
        encoded = handler.encode_utf8_url(url)

        expect { URI.parse(encoded) }.not_to raise_error,
                                             "Encoded URL '#{encoded}' from '#{url}' should be parseable by URI"

        parsed = URI.parse(encoded)
        expect(parsed.scheme).to be_present
        expect(parsed.host).to be_present if url.include?('://')
      end
    end
  end

  describe 'edge cases and error handling' do
    it 'handles URLs with multiple consecutive spaces' do
      url = 'https://example.com/path   with   spaces'
      result = handler.encode_utf8_url(url)
      expect(result).to include('%20%20%20') # Multiple spaces encoded
    end

    it 'handles URLs with mixed encodings' do
      url = 'https://example.com/caf%C3%A9 mixed'
      result = handler.encode_utf8_url(url)
      # Should handle both pre-encoded and raw characters
      expect(result).to include('%20') # space should be encoded
    end

    it 'handles very long UTF-8 URLs' do
      long_path = 'страница' * 100 # Very long Cyrillic path
      url = "https://example.com/#{long_path}"

      expect { handler.encode_utf8_url(url) }.not_to raise_error
      expect { handler.safe_parse_uri(url) }.not_to raise_error
    end

    it 'handles URLs with special characters in different positions' do
      urls = [
        'https://café.example.com', # in domain
        'https://example.com/café', # in path
        'https://example.com?café=value', # in query param name
        'https://example.com?param=café', # in query param value
        'https://example.com#café' # in fragment
      ]

      urls.each do |url|
        expect { handler.safe_parse_uri(url) }.not_to raise_error
        expect { handler.encode_utf8_url(url) }.not_to raise_error
      end
    end
  end
end
