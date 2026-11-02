# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::Http do
  subject(:http) { described_class.new }

  def response(code, body = '', headers = {})
    instance_double(Net::HTTPResponse, code: code.to_s, body: body).tap do |double|
      allow(double).to receive(:[]) { |name| headers[name] }
    end
  end

  it 'returns the body of a successful response and identifies itself' do
    allow(SsrfFilter).to receive(:get).and_return(response(200, 'ok'))

    expect(http.get('https://example.test/x')).to eq('ok')
    expect(SsrfFilter).to have_received(:get).with(
      'https://example.test/x', hash_including(headers: hash_including('User-Agent' => /BetterTogether/))
    )
  end

  it 'raises NotFound for 404' do
    allow(SsrfFilter).to receive(:get).and_return(response(404))
    expect { http.get('https://example.test/x') }.to raise_error(described_class::NotFound)
  end

  it 'raises RateLimited with the Retry-After value' do
    allow(SsrfFilter).to receive(:get).and_return(response(429, '', 'Retry-After' => '120'))
    expect { http.get('https://example.test/x') }
      .to raise_error(described_class::RateLimited) { |error| expect(error.retry_after).to eq(120) }
  end

  it 'wraps timeouts and SSRF refusals as Http::Error' do
    allow(SsrfFilter).to receive(:get).and_raise(Timeout::Error, 'slow')
    expect { http.get('https://example.test/x') }.to raise_error(described_class::Error, /Timeout/)
  end
end
