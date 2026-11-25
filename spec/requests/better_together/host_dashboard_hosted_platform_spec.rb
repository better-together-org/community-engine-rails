# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host dashboard on a hosted platform', :skip_host_setup do
  let(:locale) { I18n.default_locale }
  let(:hosted_platform) { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }
  let(:other_platform) { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }
  let(:steward) { create(:user, :confirmed, password: 'SecureTest123!@#', password_confirmation: 'SecureTest123!@#') }

  before do
    configure_host_platform
    BetterTogether::AccessControlBuilder.seed_data
    BetterTogether::PersonPlatformMembership.create!(
      joinable: hosted_platform, member: steward.person,
      role: BetterTogether::Role.find_by!(identifier: 'platform_steward'), status: 'active'
    )
    create(:better_together_page, platform: hosted_platform, identifier: 'hosted-only-page')
    create(:better_together_page, platform: other_platform, identifier: 'other-platform-page')
    host! hosted_platform.platform_domains.find_by(primary: true).hostname
    login_as(steward, scope: :user)
  end

  it 'lets a hosted steward reach the dashboard on their own domain' do
    get better_together.host_dashboard_path(locale:)

    expect(response).to have_http_status(:success)
  end

  it 'scopes the overview to the hosted platform only' do
    get better_together.host_dashboard_path(locale:)

    expect(assigns(:page_count)).to eq(hosted_platform.pages.count)
    expect(assigns(:platform_count)).to eq(1)
    expect(assigns(:pages).map(&:identifier)).not_to include('other-platform-page')
  end
end
