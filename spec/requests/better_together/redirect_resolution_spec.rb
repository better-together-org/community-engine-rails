# frozen_string_literal: true

require 'rails_helper'

# Redirects answer before routing, per platform, and old FriendlyId slugs redirect to the current one.
RSpec.describe 'Redirect resolution', :skip_host_setup do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let!(:platform_a) { create(:better_together_platform, host_url: 'http://a.redirects.test', privacy: 'public') }
  let!(:platform_b) { create(:better_together_platform, host_url: 'http://b.redirects.test') }

  before do
    Rails.cache.clear
  end

  it 'redirects a legacy path on the matching platform before the pages catch-all' do
    create(:better_together_redirect, platform: platform_a, from_path: '/omphalina/xii.html', to_path: '/en/omphalina')
    host! 'a.redirects.test'

    get '/omphalina/XII.html?ref=1'

    expect(response).to have_http_status(:moved_permanently)
    expect(response.headers['Location']).to eq('http://a.redirects.test/en/omphalina?ref=1')
  end

  it 'does not apply one platform redirect on another platform' do
    create(:better_together_redirect, platform: platform_a, from_path: '/about', to_path: '/en/elsewhere')
    host! 'b.redirects.test'

    get '/about'

    expect(response.headers['Location'].to_s).not_to include('elsewhere')
  end

  it 'lets two platforms each define the same path' do
    create(:better_together_redirect, platform: platform_a, from_path: '/about', to_path: '/en/a-about')
    create(:better_together_redirect, platform: platform_b, from_path: '/about', to_path: '/en/b-about')
    host! 'b.redirects.test'

    get '/about'

    expect(response.headers['Location']).to eq('http://b.redirects.test/en/b-about')
  end

  it 'answers 410 for a gone path and supports other statuses and external targets' do
    create(:better_together_redirect, :gone, platform: platform_a, from_path: '/retired')
    create(:better_together_redirect, platform: platform_a, from_path: '/ext', to_path: 'https://example.test/x',
                                      status: 302, preserve_query: false)
    host! 'a.redirects.test'

    get '/retired'
    expect(response).to have_http_status(:gone)

    get '/ext?a=1'
    expect(response).to have_http_status(:found)
    expect(response.headers['Location']).to eq('https://example.test/x')
  end

  it 'leaves inactive redirects and non-GET requests alone' do
    create(:better_together_redirect, platform: platform_a, from_path: '/off', active: false)
    create(:better_together_redirect, platform: platform_a, from_path: '/posty')
    host! 'a.redirects.test'

    get '/off'
    expect(response.headers['Location'].to_s).not_to include('new-page')

    expect { post '/posty' }.to raise_error(ActionController::RoutingError)
  end

  it 'counts hits' do
    redirect = create(:better_together_redirect, platform: platform_a, from_path: '/counted')
    host! 'a.redirects.test'

    get '/counted'

    expect(redirect.reload.hit_count).to eq(1)
  end

  describe 'old slugs' do
    it 'redirects a page requested by a former slug to its current slug' do
      host! 'a.redirects.test'
      page = create(:better_together_page, :published_public, platform: platform_a, slug: 'old-name', title: 'Old name')
      page.update!(slug: 'new-name')

      get "/#{locale}/old-name"

      expect(response).to have_http_status(:moved_permanently)
      expect(response.headers['Location']).to end_with("/#{locale}/new-name")
    end

    it 'still answers 404 for a slug that never existed' do
      host! 'a.redirects.test'

      get "/#{locale}/never-existed"

      expect(response).to have_http_status(:not_found)
    end
  end
end
