# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/person_platform_integrations/_integrations_list' do
  before do
    view.extend BetterTogether::OauthButtonsHelper
    configure_host_platform
    ensure_host_platform_domain
    stub_provider_env('GITHUB_CLIENT_ID', 'GITHUB_CLIENT_SECRET')
    allow(view).to receive(:omniauth_authorize_path) { |_scope, provider| "/users/auth/#{provider}" }
  end

  it 'offers only providers configured for this domain', :aggregate_failures do
    render partial: 'better_together/person_platform_integrations/integrations_list',
           locals: { person_platform_integrations: [] }

    expect(rendered).to include('/users/auth/github')
    expect(rendered).not_to include('/users/auth/google_oauth2')
    expect(rendered).not_to include('/users/auth/facebook')
    expect(rendered).not_to include('/users/auth/openid_connect')
  end
end
