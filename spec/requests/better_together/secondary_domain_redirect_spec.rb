# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Secondary domain redirect', :skip_host_setup do
  let(:platform) do
    create(:better_together_platform, host: false, privacy: 'public', host_url: 'http://club.redirect.test')
  end
  let!(:primary) { platform.platform_domains.find_by!(primary_flag: true) }
  let!(:secondary) do
    create(:better_together_platform_domain, platform:, hostname: 'old.redirect.test', primary: false, active: true)
  end

  before do
    configure_host_platform
    primary.update!(hostname: 'club.redirect.test')
  end

  it 'sends a secondary domain to the primary domain, keeping path and query' do
    host! secondary.hostname

    get "/#{I18n.locale}/communities?q=x"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to eq("http://club.redirect.test/#{I18n.locale}/communities?q=x")
  end

  it 'serves the primary domain without redirecting' do
    host! primary.hostname

    get "/#{I18n.locale}/communities"

    expect(response).not_to have_http_status(:moved_permanently)
  end

  it 'does not redirect the share domain' do
    secondary.update!(share_domain: true)
    host! secondary.hostname

    get "/#{I18n.locale}/communities"

    expect(response).not_to have_http_status(:moved_permanently)
  end

  it 'does not redirect when the platform turns the redirect off' do
    platform.update!(redirect_secondary_domains: false)
    host! secondary.hostname

    get "/#{I18n.locale}/communities"

    expect(response).not_to have_http_status(:moved_permanently)
  end

  it 'does not redirect an API path' do
    host! secondary.hostname

    get '/api/v1/communities'

    expect(response).not_to have_http_status(:moved_permanently)
  end

  it 'does not redirect a request carrying an Authorization header' do
    host! secondary.hostname

    get "/#{I18n.locale}/communities", headers: { 'Authorization' => 'Bearer token' }

    expect(response).not_to have_http_status(:moved_permanently)
  end

  it 'does not redirect a request that changes data' do
    host! secondary.hostname

    post better_together.user_session_path(locale: I18n.locale), params: { user: { email: 'a@example.test', password: 'x' } }

    expect(response).not_to have_http_status(:moved_permanently)
  end
end
