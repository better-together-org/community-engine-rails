# frozen_string_literal: true

require 'rails_helper'

# Stable ids the docs screenshots and tests depend on.
RSpec.describe 'Platform identity providers DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:base) { "/#{I18n.default_locale}/host/platforms/#{platform.to_param}/identity_providers" }
  let(:page_html) { Nokogiri::HTML(response.body) }

  before do
    github = BetterTogether::Platform.find_by(identifier: 'github', external: true) ||
             create(:better_together_platform, identifier: 'github', external: true, name: 'GitHub', url: 'https://github.com')
    create(:better_together_platform_identity_provider, platform:, provider_platform: github)
  end

  it 'exposes the index hooks', :aggregate_failures do
    get base

    %w[#new-platform-identity-provider-btn #platform-identity-providers-table
       .platform-identity-provider-secret-badge .platform-identity-provider-status-badge].each do |selector|
      expect(page_html.css(selector)).not_to be_empty, "missing #{selector}"
    end
  end

  it 'exposes the form hooks', :aggregate_failures do
    get "#{base}/new"

    %w[#platform_identity_provider_strategy #platform_identity_provider_client_id
       #platform_identity_provider_client_secret #platform_identity_provider_scopes
       #platform_identity_provider_enabled #platform-identity-provider-submit-btn
       #platform-identity-provider-cancel-btn #platform-identity-provider-domains].each do |selector|
      expect(page_html.css(selector)).not_to be_empty, "missing #{selector}"
    end
  end

  it 'never renders the stored secret into the edit form' do
    row = BetterTogether::PlatformIdentityProvider.last
    row.update!(client_secret: 'do-not-render')
    get "#{base}/#{row.id}/edit"

    expect(response.body).not_to include('do-not-render')
  end
end
