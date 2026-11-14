# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform identity providers admin', :as_platform_manager do # rubocop:disable RSpec/DescribeClass
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let!(:github_platform) do
    BetterTogether::Platform.find_by(identifier: 'github', external: true) ||
      create(:better_together_platform, identifier: 'github', external: true, name: 'GitHub', url: 'https://github.com')
  end
  let(:base) { "/#{I18n.default_locale}/host/platforms/#{platform.to_param}/identity_providers" }
  let(:page_html) { Nokogiri::HTML(response.body) }

  describe 'GET index' do
    it 'lists providers without exposing the secret', :aggregate_failures do
      row = create(:better_together_platform_identity_provider, platform:, provider_platform: github_platform,
                                                                client_secret: 'super-secret-value')
      get base

      expect(response).to have_http_status(:ok)
      expect(page_html.css("##{ActionView::RecordIdentifier.dom_id(row)}").size).to eq(1)
      expect(response.body).not_to include('super-secret-value')
    end

    it 'shows the empty state and env note when none are configured', :aggregate_failures do
      get base

      expect(page_html.css('#platform-identity-providers-empty').size).to eq(1)
      expect(page_html.css('#platform-identity-providers-env-note').size).to eq(1)
    end
  end

  describe 'GET index with environment-configured providers' do
    it 'shows them without exposing values', :aggregate_failures do
      domain = BetterTogether::PlatformDomain.find_or_create_by!(hostname: 'www.example.com') do |d|
        d.platform = platform
        d.active = true
        d.primary_flag = true
      end
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_ID', nil).and_return('env-client-id')
      allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_SECRET', nil).and_return('env-client-secret')
      get base

      expect(page_html.css('#platform-identity-provider-env-github').text).to include(domain.hostname)
      expect(response.body).not_to include('env-client-id', 'env-client-secret')
    end
  end

  describe 'POST create' do
    let(:params) do
      { platform_identity_provider: { strategy: 'github', client_id: 'abc', client_secret: 's3cret', enabled: '1' } }
    end

    it 'creates a row bound to the external provider platform', :aggregate_failures do
      expect { post base, params: }.to change(BetterTogether::PlatformIdentityProvider, :count).by(1)

      row = BetterTogether::PlatformIdentityProvider.last
      expect([row.platform, row.provider_platform, row.client_secret]).to eq([platform, github_platform, 's3cret'])
      expect(response).to redirect_to(base)
    end

    it 'stores only the allowed domains that belong to the platform', :aggregate_failures do
      own = BetterTogether::PlatformDomain.create!(platform:, hostname: 'own.example.test', active: true)
      foreign = BetterTogether::PlatformDomain.create!(platform: create(:better_together_platform),
                                                       hostname: 'foreign.example.test', active: true)
      params[:platform_identity_provider][:platform_domain_ids] = ['', own.id, foreign.id]
      post base, params: params

      row = BetterTogether::PlatformIdentityProvider.last
      expect(row.platform_domains).to include(own)
    end

    it 'rejects an unregistered strategy' do
      params[:platform_identity_provider][:strategy] = 'myspace'

      expect { post base, params: }.not_to change(BetterTogether::PlatformIdentityProvider, :count)
    end
  end

  describe 'PATCH update' do
    let!(:row) do
      create(:better_together_platform_identity_provider, platform:, provider_platform: github_platform,
                                                          client_id: 'old', client_secret: 'keep-me')
    end

    it 'keeps the stored secret when the field is left blank', :aggregate_failures do
      patch "#{base}/#{row.id}", params: { platform_identity_provider: { client_id: 'new', client_secret: '' } }

      expect(row.reload.client_id).to eq('new')
      expect(row.client_secret).to eq('keep-me')
    end

    it 'does not change the strategy of an existing row' do
      patch "#{base}/#{row.id}", params: { platform_identity_provider: { strategy: 'github', enabled: '0' } }

      expect(row.reload.enabled).to be(false)
    end
  end

  describe 'DELETE destroy' do
    it 'removes the row' do
      row = create(:better_together_platform_identity_provider, platform:, provider_platform: github_platform)

      expect { delete "#{base}/#{row.id}" }.to change(BetterTogether::PlatformIdentityProvider, :count).by(-1)
    end
  end

  describe 'platform page link' do
    it 'links to the providers screen from platform operations' do
      get "/#{I18n.default_locale}/host/platforms/#{platform.to_param}"

      expect(page_html.css('#platform-identity-providers-link').size).to eq(1)
    end
  end
end
