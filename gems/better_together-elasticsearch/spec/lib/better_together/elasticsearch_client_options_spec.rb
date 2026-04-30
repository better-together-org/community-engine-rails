# frozen_string_literal: true

require_relative '../../rails_helper'

RSpec.describe BetterTogether::ElasticsearchClientOptions do
  describe '.enabled?' do
    it 'returns true when the elasticsearch backend is selected explicitly' do
      expect(described_class.enabled?('SEARCH_BACKEND' => 'elasticsearch')).to be(true)
    end

    it 'returns false when only elasticsearch connection settings are present' do
      expect(described_class.enabled?('ELASTICSEARCH_URL' => 'http://example.test:9200')).to be(false)
    end

    it 'returns false when neither backend selection nor connection settings are present' do
      expect(described_class.enabled?({})).to be(false)
    end
  end

  describe '.build' do
    it 'builds a client config from a single URL' do
      env = { 'ELASTICSEARCH_URL' => 'http://example.test:9200' }

      options = described_class.build(env)

      expect(options[:url]).to eq('http://example.test:9200')
      expect(options[:retry_on_failure]).to be(true)
      expect(options[:reload_connections]).to be(true)
      expect(options.dig(:transport_options, :request, :timeout)).to eq(5)
      expect(options.dig(:transport_options, :request, :open_timeout)).to eq(2)
    end

    it 'injects basic auth credentials when provided separately' do
      env = {
        'ELASTICSEARCH_URL' => 'https://search.example.test:9200',
        'ELASTICSEARCH_USERNAME' => 'elastic',
        'ELASTICSEARCH_PASSWORD' => 'secret'
      }

      options = described_class.build(env)

      expect(options[:url]).to eq('https://elastic:secret@search.example.test:9200')
    end

    it 'preserves credentials already present in the URL' do
      env = {
        'ELASTICSEARCH_URL' => 'https://built:in@search.example.test:9200',
        'ELASTICSEARCH_USERNAME' => 'elastic',
        'ELASTICSEARCH_PASSWORD' => 'secret'
      }

      options = described_class.build(env)

      expect(options[:url]).to eq('https://built:in@search.example.test:9200')
    end

    it 'builds the URL from host and port fallback env vars' do
      env = {
        'ES_HOST' => 'http://elasticsearch',
        'ES_PORT' => '9201'
      }

      options = described_class.build(env)

      expect(options[:url]).to eq('http://elasticsearch:9201')
    end

    it 'passes CA file, fingerprint, and SSL verify options when configured' do
      env = {
        'ELASTICSEARCH_URL' => 'https://search.example.test:9200',
        'ELASTICSEARCH_CA_CERT_FILE' => '/certs/http_ca.crt',
        'ELASTICSEARCH_CA_FINGERPRINT' => 'AA:BB:CC',
        'ELASTICSEARCH_SSL_VERIFY' => 'false'
      }

      options = described_class.build(env)

      expect(options[:ca_fingerprint]).to eq('AA:BB:CC')
      expect(options.dig(:transport_options, :ssl, :ca_file)).to eq('/certs/http_ca.crt')
      expect(options.dig(:transport_options, :ssl, :verify)).to be(false)
    end
  end
end
