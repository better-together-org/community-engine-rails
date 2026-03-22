# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe BetterTogether::Metrics::HttpLinkChecker do
  it 'returns success for 200 head response' do
    stub_request(:head, 'https://ok.test/').to_return(status: 200)

    result = described_class.new('https://ok.test/').call

    # success + status code present and no error
    expect([result.success, result.status_code, result.error]).to eq([true, '200', nil])
  end

  it 'retries and returns failure for unreachable host' do
    stub_request(:head, 'https://nope.test/').to_timeout

    result = described_class.new('https://nope.test/', retries: 1).call

    # failed, no status_code, error present (error should be a StandardError ancestor)
    expect(result.success).to be(false)
    expect(result.status_code).to be_nil
    expect(result.error).to be_a(StandardError)
  end

  describe 'invalid URI handling' do
    it 'returns failure without raising for non-ASCII URI (French accented slug)' do
      stub_request(:head, 'https://example.com/fr%C3%A9quemment-pos%C3%A9es').to_timeout

      result = described_class.new('https://example.com/fréquemment-posées').call

      expect(result.success).to be(false)
      expect(result.status_code).to be_nil
      expect(result.error).to be_a(StandardError)
    end

    it 'returns failure without raising for CSS gradient stored as href' do
      gradient_uri = 'linear-gradient(to bottom, #ffffff 0%, #000000 100%)'
      result = described_class.new(gradient_uri).call

      expect(result.success).to be(false)
      expect(result.status_code).to be_nil
      expect(result.error).to be_a(StandardError)
    end

    it 'does not raise URI::InvalidURIError for malformed URIs' do
      stub_request(:head, 'https://example.com/path%20with%20spaces').to_timeout

      expect do
        described_class.new('https://example.com/path with spaces').call
      end.not_to raise_error
    end
  end
end
