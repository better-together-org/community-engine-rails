# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformIdentityProvider, '#client_secret handling' do # rubocop:disable RSpec/SpecFilePathFormat
  let(:secret) { 'sup3r-s3cret-value' }
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  it 'filters the secret from request parameters' do
    params = { 'platform_identity_provider' => { 'client_id' => 'abc', 'client_secret' => secret } }

    expect(filter.filter(params).dig('platform_identity_provider', 'client_secret')).to eq('[FILTERED]')
  end

  it 'omits the secret from inspect and serialization' do
    record = described_class.new(strategy: 'github', client_id: 'abc', client_secret: secret)

    expect([record.inspect, record.to_json, record.serializable_hash.to_s].join).not_to include(secret)
  end

  it 'strips whitespace around credentials' do
    record = described_class.new(client_id: ' abc ', client_secret: " #{secret}\n")

    expect([record.client_id, record.client_secret]).to eq(['abc', secret])
  end

  it 'rejects embedded whitespace and control characters' do
    record = described_class.new(strategy: 'github', client_id: 'a b', client_secret: "se\ncret")
    record.valid?

    expect(record.errors.attribute_names).to include(:client_id, :client_secret)
  end

  it 'redacts the secret in the resolved credentials object' do
    creds = BetterTogether::IdentityProviderCredentials::Result.new(client_id: 'abc', client_secret: secret,
                                                                    scope: 'x', options: {})

    expect([creds.inspect, creds.to_s, creds.to_h.to_s, creds.to_json].join).not_to include(secret)
  end

  it 'still hands the real secret to OmniAuth' do
    creds = BetterTogether::IdentityProviderCredentials::Result.new(client_id: 'abc', client_secret: secret,
                                                                    scope: nil, options: {})
    options = {}
    BetterTogether::OmniauthSetup.apply(options, creds)

    expect(options[:client_secret]).to eq(secret)
  end
end
