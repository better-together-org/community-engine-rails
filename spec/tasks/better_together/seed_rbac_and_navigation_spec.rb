# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:seed:rbac_and_navigation' do
  before(:all) do
    Rake.application = Rake::Application.new
    Rake.application.rake_require(
      'tasks/better_together/seed_rbac_and_navigation',
      [BetterTogether::Engine.root.join('lib').to_s]
    )
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['better_together:seed:rbac_and_navigation'] }

  before do
    task.reenable
  end

  it 'ensures analytics navigation and RBAC data are present' do
    legacy_permission = BetterTogether::ResourcePermission.create!(
      action: 'view',
      target: 'platform_analytics',
      resource_type: 'BetterTogether::Platform',
      identifier: 'view_platform_analytics',
      protected: true
    )
    legacy_role = BetterTogether::Role.create!(
      identifier: 'platform_analytics',
      resource_type: 'BetterTogether::Platform',
      name: 'Platform Analytics (Legacy)',
      protected: true
    )

    legacy_role.assign_resource_permissions([legacy_permission.identifier])

    platform = create(:better_together_platform)
    person = create(:better_together_person)
    membership = create(
      :person_platform_membership,
      joinable: platform,
      member: person,
      role: legacy_role
    )
    invitation = create(
      :platform_invitation,
      invitable: platform,
      platform_role: legacy_role
    )

    task.invoke

    analytics_role = BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer')
    expect(analytics_role).to be_present

    view_permission = BetterTogether::ResourcePermission.find_by(identifier: 'view_metrics_dashboard')
    create_permission = BetterTogether::ResourcePermission.find_by(identifier: 'create_metrics_reports')
    download_permission = BetterTogether::ResourcePermission.find_by(identifier: 'download_metrics_reports')

    expect(view_permission).to be_present
    expect(create_permission).to be_present
    expect(download_permission).to be_present

    platform_manager = BetterTogether::Role.find_by(identifier: 'platform_manager')
    expect(platform_manager).to be_present
    expect(platform_manager.resource_permissions.map(&:identifier)).to include(
      'view_metrics_dashboard',
      'create_metrics_reports',
      'download_metrics_reports'
    )

    analytics_nav_item = BetterTogether::NavigationItem.find_by(identifier: 'analytics')
    expect(analytics_nav_item).to be_present
    expect(analytics_nav_item.route_name).to eq('metrics_reports_url')
    expect(analytics_nav_item.permission_identifier).to eq('view_metrics_dashboard')
    expect(analytics_nav_item.visibility_strategy).to eq('permission')

    legacy_permission = BetterTogether::ResourcePermission.find_by(identifier: 'view_platform_analytics')
    expect(legacy_permission).to be_nil

    expect(
      BetterTogether::PersonPlatformMembership.find_by(
        member_id: membership.member_id,
        joinable_id: membership.joinable_id,
        role_id: analytics_role.id
      )
    ).to be_present
    expect(invitation.reload.platform_role_id).to eq(analytics_role.id)
  end
end
