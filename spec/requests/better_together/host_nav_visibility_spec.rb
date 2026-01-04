# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host nav visibility for analytics viewer', :no_auth do
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:user) { create(:better_together_user, :confirmed) }

  before do
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

    navigation_area = BetterTogether::NavigationArea.find_or_create_by!(
      identifier: 'platform-host'
    ) do |area|
      area.name = 'Platform Host'
      area.slug = 'platform-host'
      area.visible = true
      area.protected = true
    end

    host_nav = BetterTogether::NavigationItem.find_or_create_by!(
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
end
