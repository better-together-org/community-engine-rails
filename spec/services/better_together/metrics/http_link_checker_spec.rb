# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

module BetterTogether
  RSpec.describe Metrics::HttpLinkChecker do
    it 'returns success for 200 head response' do
      stub_request(:head, 'https://ok.test/').to_return(status: 200)

      result = described_class.new('https://ok.test/').call

      # success + status code present and no error
      expect([result.success, result.status_code, result.error]).to eq([true, '200', nil])
    end

    it 'retries and returns failure for unreachable host' do
      stub_request(:head, 'https://nope.test/').to_timeout

      result = described_class.new('https://nope.test/', retries: 1).call

      # failed, no status_code, error present
      expect([result.success, result.status_code, result.error.class]).to eq([false, nil, StandardError])
    end
  end
end
