# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RBAC index navigation counts', :skip_host_setup do
  let(:locale) { I18n.default_locale }
  let(:hosted_platform) { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }
  let(:other_platform) { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }
  let(:steward) { create(:user, :confirmed) }

  before do
    configure_host_platform
    BetterTogether::AccessControlBuilder.seed_data
    BetterTogether::PersonPlatformMembership.create!(
      joinable: hosted_platform, member: steward.person,
      role: BetterTogether::Role.find_by!(identifier: 'platform_steward'), status: 'active'
    )
    create(:better_together_role, :platform_role, platform: hosted_platform)
    create_list(:better_together_role, 2, :platform_role, platform: other_platform)
    host! hosted_platform.platform_domains.find_by(primary: true).hostname
    login_as(steward, scope: :user)
  end

  it 'counts only the viewed platform on the roles index' do
    get better_together.roles_path(locale:)

    expect(response).to have_http_status(:success)
    counts = assigns(:rbac_nav_counts)
    expect(counts[:roles]).to eq(BetterTogether::Role.where(platform_id: hosted_platform.id).count)
    expect(counts[:resource_permissions])
      .to eq(BetterTogether::ResourcePermission.where(platform_id: hosted_platform.id).count)
    expect(counts[:resource_permissions]).to be < BetterTogether::ResourcePermission.count
  end

  it 'counts only the viewed platform on the resource permissions index' do
    get better_together.resource_permissions_path(locale:)

    expect(response).to have_http_status(:success)
    counts = assigns(:rbac_nav_counts)
    expect(counts[:roles]).to eq(BetterTogether::Role.where(platform_id: hosted_platform.id).count)
    expect(counts[:roles]).to be < BetterTogether::Role.count
  end
end
