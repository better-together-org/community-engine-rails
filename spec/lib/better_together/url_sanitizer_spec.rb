# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::UrlSanitizer do
  describe '.encode_path' do
    it 'percent-encodes double quotes and commas' do
      encoded = described_class.encode_path('"hello",world')

      expect(encoded).to eq('%22hello%22%2Cworld')
    end

    it 'still percent-encodes the previously-covered unsafe ASCII delimiters' do
      encoded = described_class.encode_path('[a] {b} c\\d^e`f|g<h>i j')

      expect(encoded).not_to match(/[\[\]{}\\^`|<>\s]/)
    end

    it 'still percent-encodes non-ASCII bytes' do
      encoded = described_class.encode_path('à-propos-de-nous')

      expect(encoded).to eq('%C3%A0-propos-de-nous')
    end

    # Regression: the exact scanner probe observed in production Sentry issue #140848411
    # (URI::InvalidURIError: bad URI (is not URI?): "/en/    \"/panel/\","). Before this
    # fix, encode_path left the quote and comma unescaped, so URI.parse still raised.
    it 'produces a path that URI.parse accepts for the exact reported scanner probe' do
      probe_path = '    "/panel/",'
      encoded = described_class.encode_path(probe_path)

      expect { URI.parse("/#{I18n.default_locale}/#{encoded}") }.not_to raise_error
    end
  end
end
