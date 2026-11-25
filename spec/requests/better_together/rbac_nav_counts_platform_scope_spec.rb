# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RBAC index navigation counts', :skip_host_setup do
  let(:locale) { I18n.default_locale }
  let(:setup) { managed_platform_setup }
  let(:hosted_platform) { setup.managed_platform }
  let(:other_platform) { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }

  before do
    create(:better_together_role, :platform_role, platform: hosted_platform)
    create_list(:better_together_role, 2, :platform_role, platform: other_platform)
    host_on(hosted_platform)
    sign_in_steward(setup.managed_steward)
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
