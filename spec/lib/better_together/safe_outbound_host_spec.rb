# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SafeOutboundHost do
  before do
    allow(Resolv).to receive(:getaddresses).with('public.example.org').and_return(['93.184.216.34'])
    allow(Resolv).to receive(:getaddresses).with('meta.example.org').and_return(['169.254.169.254'])
  end

  it 'accepts a hostname with only public addresses' do
    expect(described_class.assert_public!('public.example.org')).to be(true)
  end

  it 'refuses a hostname resolving to link-local space' do
    expect { described_class.assert_public!('meta.example.org') }.to raise_error(described_class::UnsafeHost)
  end

  it 'refuses loopback, private and mapped IP literals' do
    %w[127.0.0.1 10.0.0.1 192.168.1.1 ::1 ::ffff:127.0.0.1].each do |literal|
      expect(described_class.public_host?(literal)).to be(false), literal
    end
  end

  it 'guards each Faraday request, including endpoints named by a discovery document' do
    stack = Faraday.new do |f|
      f.use described_class::Guard
      f.adapter :test do |s|
        s.get('/x') { [200, {}, 'ok'] }
      end
    end
    expect { stack.get('http://meta.example.org/x') }.to raise_error(described_class::UnsafeHost)
  end
end
