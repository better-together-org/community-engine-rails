# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host nav visibility for analytics viewer', :no_auth do
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:user) { create(:better_together_user, :confirmed) }
  let(:navigation_area) do
    BetterTogether::NavigationArea.find_or_create_by!(identifier: 'platform-host') do |area|
      area.name = 'Platform Host'
      area.slug = 'platform-host'
      area.visible = true
      area.protected = true
    end
  end
  let(:host_nav) do
    BetterTogether::NavigationItem.find_or_create_by!(
      identifier: 'host-nav',
      navigation_area: navigation_area,
      parent_id: nil
    ) do |item|
      item.title = 'Host'
      item.slug = 'host-nav'
      item.position = 0
      item.visible = true
      item.protected = true
      item.item_type = 'dropdown'
      item.url = '#'
    end
  end

  before do
    BetterTogether::AccessControlBuilder.seed_data

    permission = BetterTogether::ResourcePermission.find_or_create_by(
      identifier: 'view_metrics_dashboard',
      resource_type: 'BetterTogether::Platform'
    ) do |perm|
      perm.action = 'view'
      perm.target = 'metrics_dashboard'
      perm.protected = true
    end

    role = BetterTogether::Role.find_or_create_by(
      identifier: 'platform_analytics_viewer',
      resource_type: 'BetterTogether::Platform'
    ) do |role_record|
      role_record.name = 'Platform Analytics Viewer'
      role_record.protected = true
      role_record.position = 10
    end

    role.resource_permissions << permission unless role.resource_permissions.exists?(id: permission.id)

    BetterTogether::PersonPlatformMembership.create!(
      member: user.person,
      joinable: host_platform,
      role: role
    )

    host_nav.update!(
      privacy: 'private',
      visibility_strategy: 'permission',
      permission_identifier: 'view_metrics_dashboard',
      visible: true
    )

    login(user.email, 'SecureTest123!@#')
  end

  it 'renders host nav in the user dropdown' do
    get better_together.home_page_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('host-nav-item')
  end

  it 'does not expose host dashboard review entries without matching permissions' do
    BetterTogether::NavigationItem.find_or_create_by!(
      identifier: 'host-dashboard-membership-review',
      navigation_area: navigation_area,
      parent: host_nav
    ) do |item|
      item.title = 'Membership Review'
      item.slug = 'host-dashboard-membership-review'
      item.position = 15
      item.visible = true
      item.protected = true
      item.item_type = 'link'
      item.route_name = 'host_dashboard_membership_review_url'
      item.privacy = 'private'
      item.visibility_strategy = 'permission'
      item.permission_identifier = 'manage_platform'
    end

    BetterTogether::NavigationItem.find_or_create_by!(
      identifier: 'host-dashboard-safety-review',
      navigation_area: navigation_area,
      parent: host_nav
    ) do |item|
      item.title = 'Safety Review'
      item.slug = 'host-dashboard-safety-review'
      item.position = 21
      item.visible = true
      item.protected = true
      item.item_type = 'link'
      item.route_name = 'host_dashboard_safety_review_url'
      item.privacy = 'private'
      item.visibility_strategy = 'permission'
      item.permission_identifier = 'manage_platform_safety'
    end

    BetterTogether::NavigationItem.find_or_create_by!(
      identifier: 'host-dashboard-platform-connection-review',
      navigation_area: navigation_area,
      parent: host_nav
    ) do |item|
      item.title = 'Federation Review'
      item.slug = 'host-dashboard-platform-connection-review'
      item.position = 20
      item.visible = true
      item.protected = true
      item.item_type = 'link'
      item.route_name = 'host_dashboard_platform_connection_review_url'
      item.privacy = 'private'
      item.visibility_strategy = 'permission'
      item.permission_identifier = 'manage_network_connections'
    end

    get better_together.home_page_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Membership Review')
    expect(response.body).not_to include('Safety Review')
    expect(response.body).not_to include('Federation Review')
  end

  it 'shows the safety review nav entry when the user has safety review permission' do
    safety_permission = BetterTogether::ResourcePermission.find_by!(identifier: 'manage_platform_safety')
    safety_role = create(:better_together_role, :platform_role)
    safety_role.assign_resource_permissions([safety_permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role: safety_role)

    BetterTogether::NavigationItem.find_or_create_by!(
      identifier: 'host-dashboard-safety-review',
      navigation_area: navigation_area,
      parent: host_nav
    ) do |item|
      item.title = 'Safety Review'
      item.slug = 'host-dashboard-safety-review'
      item.position = 21
      item.visible = true
      item.protected = true
      item.item_type = 'link'
      item.route_name = 'host_dashboard_safety_review_url'
      item.privacy = 'private'
      item.visibility_strategy = 'permission'
      item.permission_identifier = 'manage_platform_safety'
    end

    get better_together.home_page_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Safety Review')
  end

  it 'shows the membership review nav entry when the user can manage the platform' do
    manage_platform_permission = BetterTogether::ResourcePermission.find_by!(identifier: 'manage_platform')
    manage_platform_role = create(:better_together_role, :platform_role)
    manage_platform_role.assign_resource_permissions([manage_platform_permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role: manage_platform_role)

    BetterTogether::NavigationItem.find_or_create_by!(
      identifier: 'host-dashboard-membership-review',
      navigation_area: navigation_area,
      parent: host_nav
    ) do |item|
      item.title = 'Membership Review'
      item.slug = 'host-dashboard-membership-review'
      item.position = 15
      item.visible = true
      item.protected = true
      item.item_type = 'link'
      item.route_name = 'host_dashboard_membership_review_url'
      item.privacy = 'private'
      item.visibility_strategy = 'permission'
      item.permission_identifier = 'manage_platform'
    end

    get better_together.home_page_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Membership Review')
  end

  it 'shows the federation review nav entry when the user can review network connections' do
    network_permission = BetterTogether::ResourcePermission.find_by!(identifier: 'approve_network_connections')
    network_role = create(:better_together_role, :platform_role)
    network_role.assign_resource_permissions([network_permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role: network_role)

    BetterTogether::NavigationItem.find_or_create_by!(
      identifier: 'host-dashboard-platform-connection-review',
      navigation_area: navigation_area,
      parent: host_nav
    ) do |item|
      item.title = 'Federation Review'
      item.slug = 'host-dashboard-platform-connection-review'
      item.position = 20
      item.visible = true
      item.protected = true
      item.item_type = 'link'
      item.route_name = 'host_dashboard_platform_connection_review_url'
      item.privacy = 'private'
      item.visibility_strategy = 'permission'
      item.permission_identifier = 'manage_network_connections'
    end

    get better_together.home_page_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Federation Review')
  end
end
