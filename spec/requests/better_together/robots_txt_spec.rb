# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'robots.txt' do
  include BetterTogether::DeviseSessionHelpers

  let!(:host_platform) { configure_host_platform }

  before do
    host! 'www.example.com'
    host_platform.update!(privacy: 'public', host_url: 'http://www.example.com')
  end

  it 'is served as text/plain' do
    get '/robots.txt'

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/plain')
  end

  it 'advertises the index and per-locale sitemaps on the resolved host' do
    get '/robots.txt'

    expect(response.body).to include('Sitemap: http://www.example.com/sitemap.xml.gz')
    I18n.available_locales.each do |locale|
      expect(response.body).to include("Sitemap: http://www.example.com/#{locale}/sitemap.xml.gz")
    end
  end

  it 'disallows the management route scope' do
    get '/robots.txt'

    expect(response.body).to include("Disallow: /#{BetterTogether.route_scope_path}/")
  end

  context 'when the request host resolves to a different platform domain' do
    let!(:tenant_platform) do
      create(:better_together_platform, :public, host: false, external: false,
                                                 host_url: 'https://tenant.example.test')
    end

    it 'advertises that platform sitemap host' do
      host! 'tenant.example.test'

      get '/robots.txt'

      expect(response.body).to include('Sitemap: https://tenant.example.test/sitemap.xml.gz')
      expect(response.body).not_to include('www.example.com')
    end
  end

  context 'when the resolved platform is not public' do
    before { host_platform.update!(privacy: 'private') }

    it 'blocks all crawlers and advertises no sitemap' do
      get '/robots.txt'

      expect(response.body).to eq("User-agent: *\nDisallow: /\n")
    end
  end
end
