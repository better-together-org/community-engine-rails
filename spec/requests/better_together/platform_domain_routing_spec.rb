# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform domain routing' do
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  before do
    host_platform.update!(
      host_url: 'https://primary.example.test',
      privacy: 'public',
      requires_invitation: false
    )

    create(:better_together_platform_domain,
           platform: host_platform,
           hostname: 'alias.example.test',
           primary: false,
           active: true)
  end

  after do
    host_platform.update_columns(host_url: 'http://www.example.com')
  end

  it 'renders canonical links on the primary domain when requested from an alias hostname' do
    host! 'alias.example.test'

    get better_together.home_page_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('href="https://primary.example.test/en"')
  end

  it 'resolves the host platform from the alias domain' do
    host! 'alias.example.test'

    get better_together.home_page_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(controller.helpers.host_platform).to eq(host_platform)
  end
end
