# frozen_string_literal: true

require 'rails_helper'
require 'swagger_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'swagger_helper configuration' do
  describe 'build_swagger_servers' do
    it 'returns an array of server configurations' do
      servers = build_swagger_servers
      expect(servers).to be_an(Array)
      expect(servers).not_to be_empty
    end

    it 'includes the configured base URL' do
      servers = build_swagger_servers
      base_url_server = servers.find { |s| s[:url] == BetterTogether.base_url }

      expect(base_url_server).not_to be_nil
      expect(base_url_server[:url]).to eq(BetterTogether.base_url)
      expect(base_url_server[:description]).to include(Rails.env.capitalize)
    end

    context 'in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      # rubocop:disable RSpec/NestedGroups
      context 'when base URL is not localhost' do
        before do
          allow(BetterTogether).to receive(:base_url).and_return('https://dev.example.com')
        end

        it 'includes both configured URL and localhost' do
          servers = build_swagger_servers

          expect(servers.length).to eq(2)
          expect(servers[0][:url]).to eq('https://dev.example.com')
          expect(servers[1][:url]).to eq('http://localhost:3000')
        end

        it 'labels localhost as local development server' do
          servers = build_swagger_servers
          localhost_server = servers.find { |s| s[:url] == 'http://localhost:3000' }

          expect(localhost_server[:description]).to eq('Local development server')
        end
      end
      # rubocop:enable RSpec/NestedGroups

      # rubocop:disable RSpec/NestedGroups
      context 'when base URL is localhost' do
        before do
          allow(BetterTogether).to receive(:base_url).and_return('http://localhost:3000')
        end

        it 'includes only one server entry' do
          servers = build_swagger_servers

          expect(servers.length).to eq(1)
          expect(servers[0][:url]).to eq('http://localhost:3000')
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end

    context 'in production environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(BetterTogether).to receive(:base_url).and_return('https://api.example.com')
      end

      it 'includes only the production URL' do
        servers = build_swagger_servers

        expect(servers.length).to eq(1)
        expect(servers[0][:url]).to eq('https://api.example.com')
        expect(servers[0][:description]).to eq('Production server')
      end
    end

    context 'in test environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
        allow(BetterTogether).to receive(:base_url).and_return('http://localhost:3000')
      end

      it 'includes the test URL' do
        servers = build_swagger_servers

        expect(servers.length).to eq(1)
        expect(servers[0][:url]).to eq('http://localhost:3000')
        expect(servers[0][:description]).to eq('Test server')
      end
    end
  end

  describe 'RSpec.configuration' do
    it 'sets openapi_root to engine swagger directory' do
      expect(RSpec.configuration.openapi_root).to eq(
        BetterTogether::Engine.root.join('swagger').to_s
      )
    end

    it 'configures openapi format as yaml' do
      expect(RSpec.configuration.openapi_format).to eq(:yaml)
    end

    describe 'openapi_specs configuration' do
      let(:swagger_config) { RSpec.configuration.openapi_specs['v1/swagger.yaml'] }

      it 'defines v1/swagger.yaml document' do
        expect(swagger_config).not_to be_nil
      end

      it 'uses OpenAPI 3.0.1 specification' do
        expect(swagger_config[:openapi]).to eq('3.0.1')
      end

      it 'includes API title and version' do
        expect(swagger_config[:info][:title]).to eq('Community Engine API')
        expect(swagger_config[:info][:version]).to eq('v1')
      end

      it 'includes authentication documentation' do
        expect(swagger_config[:info][:description]).to include('Authentication')
        expect(swagger_config[:info][:description]).to include('JWT')
      end

      it 'configures bearer authentication scheme' do
        bearer_auth = swagger_config[:components][:securitySchemes][:bearer_auth]

        expect(bearer_auth[:type]).to eq(:http)
        expect(bearer_auth[:scheme]).to eq(:bearer)
        expect(bearer_auth[:bearerFormat]).to eq('JWT')
      end

      it 'includes ValidationErrors schema' do
        validation_errors = swagger_config[:components][:schemas][:ValidationErrors]

        expect(validation_errors[:type]).to eq(:object)
        expect(validation_errors[:properties][:errors]).not_to be_nil
      end

      it 'includes User schema' do
        user_schema = swagger_config[:components][:schemas][:User]

        expect(user_schema[:type]).to eq(:object)
        expect(user_schema[:properties][:id]).not_to be_nil
        expect(user_schema[:properties][:email]).not_to be_nil
        expect(user_schema[:required]).to include('id', 'email', 'created_at')
      end

      it 'includes environment-aware servers' do
        expect(swagger_config[:servers]).to be_an(Array)
        # Test that it uses the configured base_url (don't assume specific value to avoid parallel test pollution)
        expect(swagger_config[:servers].first[:url]).to eq(BetterTogether.base_url)
        expect(swagger_config[:servers].first[:url]).to match(%r{^https?://})
        expect(swagger_config[:servers].first[:description]).to include('server')
      end

      it 'initializes with empty paths object' do
        expect(swagger_config[:paths]).to eq({})
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
