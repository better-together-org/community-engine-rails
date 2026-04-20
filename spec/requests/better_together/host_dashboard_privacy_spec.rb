# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::HostDashboard privacy' do
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

  let(:locale) { I18n.default_locale }
  let(:platform_manager) do
    find_or_create_test_user('host-dashboard-manager@example.test', 'SecureTest123!@#', :platform_manager)
  end

  before do
    sign_in platform_manager
  end

  it 'does not assign private directory or account cards by default' do
    get better_together.host_dashboard_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(assigns(:show_people_card)).to be(false)
    expect(assigns(:show_user_card)).to be(false)
    expect(assigns(:people)).to be_nil
    expect(assigns(:users)).to be_nil
    expect(assigns(:conversations)).to be_nil
    expect(assigns(:messages)).to be_nil
  end

  it 'assigns people and users only when explicitly permitted' do
    grant_platform_permission(platform_manager, 'list_person')
    grant_platform_permission(platform_manager, 'manage_platform_users')

    get better_together.host_dashboard_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(assigns(:show_people_card)).to be(true)
    expect(assigns(:show_user_card)).to be(true)
    expect(assigns(:person_count)).to be_present
    expect(assigns(:user_count)).to be_present
  end
end
