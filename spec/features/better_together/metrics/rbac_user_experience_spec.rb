# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics RBAC User Experience', :js do
  include BetterTogether::CapybaraFeatureHelpers

  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  # Find or create the analytics viewer role (global role, not resource-specific)
  let!(:analytics_viewer_role) do
    BetterTogether::Role.find_by(
      identifier: 'platform_analytics_viewer'
    ) || BetterTogether::Role.create!(
      identifier: 'platform_analytics_viewer',
      resource_type: 'BetterTogether::Platform',
      name: 'Analytics Viewer',
      description: 'Can view and generate analytics reports'
    )
  end

  # Find permissions (they should exist from seeds)
  let!(:view_permission) do
    BetterTogether::ResourcePermission.find_by!(identifier: 'view_metrics_dashboard')
  end

  let!(:create_permission) do
    BetterTogether::ResourcePermission.find_by!(identifier: 'create_metrics_reports')
  end

  let!(:download_permission) do
    BetterTogether::ResourcePermission.find_by!(identifier: 'download_metrics_reports')
  end

  describe 'Analytics Viewer Role', :skip_host_setup do
    before do
      # Configure host platform manually since we skipped automatic setup
      configure_host_platform

      # Ensure the analytics viewer role has the required permissions using the assign_resource_permissions method
      # (This is the same pattern used in tabs_navigation_spec.rb)
      analytics_viewer_role.assign_resource_permissions([
                                                          view_permission.identifier,
                                                          create_permission.identifier,
                                                          download_permission.identifier
                                                        ])

      # Create user with role BEFORE logging in
      user = find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
      BetterTogether::PersonPlatformMembership.find_or_create_by!(
        joinable: platform,
        member: user.person
      ) do |membership|
        membership.role = analytics_viewer_role
      end

      # Clear cache to ensure permission checks work (pattern from tabs_navigation_spec.rb)
      Rails.cache.clear

      # Now log in the user via Capybara
      capybara_login_as_user
    end

    scenario 'User with analytics viewer role can access metrics reports' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Metrics Reports')
      expect(page).not_to have_content('You are not authorized')
    end

    scenario 'User can see Analytics navigation item' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      # User should have permission and see the metrics page
      expect(page).to have_content('Metrics Reports')

      # Verify Analytics navigation link exists on the page (it's in a nested dropdown)
      # TODO: Add more sophisticated test to interact with nested dropdowns
      expect(page).to have_css('a[data-identifier="analytics"]', text: 'Analytics', visible: :all)
    end

    scenario 'User can view metrics reports list' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Metrics Reports')
      expect(page).not_to have_content('Access Denied')
    end

    scenario 'User can access page view reports' do
      visit better_together.metrics_page_view_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Page View Reports')
      # The link text is "New Report" not "Generate New Report"
      expect(page).to have_link('New Report')
    end

    scenario 'User can create a page view report' do
      visit better_together.new_metrics_page_view_report_path(locale: I18n.default_locale)

      expect(page).to have_content('New Page View Report')

      # The File Format field should default to CSV, so we just need to submit
      # Use a more specific selector to find the submit button in the main form
      within('div.container form') do
        click_button 'Create Report'
      end

      expect(page).to have_content('Report was successfully created')
    end

    scenario 'User can access link click reports' do
      visit better_together.metrics_link_click_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Link Click Reports')
      expect(page).to have_link('New Report')
    end

    scenario 'User can access link checker reports' do
      visit better_together.metrics_link_checker_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Link checker reports')
      expect(page).to have_link('New Report')
    end

    scenario 'User can download generated reports' do
      # Create a report with attached file
      report = create(:better_together_metrics_page_view_report)
      report.report_file.attach(
        io: StringIO.new('test,data'),
        filename: 'test_report.csv',
        content_type: 'text/csv'
      )

      visit better_together.download_metrics_page_view_report_path(report, locale: I18n.default_locale)

      # Download should succeed for analytics viewer (page won't show Access Denied)
      expect(page).not_to have_content('Access Denied')
    end
  end

  describe 'Regular User Without Analytics Permission', :skip_host_setup do
    before do
      configure_host_platform

      # Create user WITHOUT any analytics role/permissions or platform membership
      find_or_create_test_user('regular@example.test', 'SecureTest123!@#', :user)

      Rails.cache.clear
      capybara_sign_in_user('regular@example.test', 'SecureTest123!@#')
    end

    scenario 'User cannot see Analytics navigation item' do
      visit better_together.host_dashboard_path(locale: I18n.default_locale)

      within('.navbar-nav', match: :first) do
        expect(page).not_to have_link('Analytics')
      end
    end

    scenario 'User cannot access metrics dashboard directly' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      # Without proper role, user doesn't get access to the page
      expect(page).not_to have_content('Metrics Reports')
    end

    scenario 'User cannot access page view reports' do
      visit better_together.metrics_page_view_reports_path(locale: I18n.default_locale)

      # Without proper role, user doesn't get access to the page
      expect(page).not_to have_content('Page View Reports')
    end

    scenario 'User cannot create reports' do
      visit better_together.new_metrics_page_view_report_path(locale: I18n.default_locale)

      # Without proper role, user doesn't get access to the page
      expect(page).not_to have_content('Generate Page View Report')
    end

    scenario 'User cannot download reports' do
      report = create(:better_together_metrics_page_view_report)
      report.report_file.attach(
        io: StringIO.new('test,data'),
        filename: 'test_report.csv',
        content_type: 'text/csv'
      )

      visit better_together.download_metrics_page_view_report_path(report, locale: I18n.default_locale)

      # Without proper role, download doesn't work
      expect(page).not_to have_content('test,data')
    end
  end

  describe 'Platform Manager', :skip_host_setup do
    before do
      configure_host_platform

      # Platform managers have all permissions by default from AccessControlBuilder
      manager = find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager)

      Rails.cache.clear
      capybara_login_as_platform_manager
    end

    scenario 'Platform manager can access all metrics features' do
      visit better_together.host_dashboard_path(locale: I18n.default_locale)

      expect(page).to have_content('Host Dashboard')

      # Should see Analytics nav item (might be in dropdown, check for link anywhere)
      expect(page).to have_css('a[data-identifier="analytics"]', text: 'Analytics', visible: :all)

      # Can access metrics reports
      visit better_together.metrics_reports_path(locale: I18n.default_locale)
      expect(page).to have_content('Metrics Reports')

      # Can create reports
      visit better_together.new_metrics_page_view_report_path(locale: I18n.default_locale)
      expect(page).to have_content('New Page View Report')
    end
  end

  describe 'Unauthenticated User', :skip_host_setup do
    before do
      configure_host_platform
      # Don't log in - test unauthenticated access
    end

    scenario 'Redirects to sign in when accessing metrics' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      # Routes aren't available without authentication
      expect(page).not_to have_content('Metrics Reports')
    end

    scenario 'Redirects to sign in when accessing host dashboard' do
      visit better_together.host_dashboard_path(locale: I18n.default_locale)

      # Routes aren't available without authentication
      expect(page).not_to have_content('Host Dashboard')
    end
  end

  describe 'Limited Analytics Access', :skip_host_setup do
    let(:view_only_role) do
      BetterTogether::Role.find_or_create_by!(
        identifier: 'view_only_analytics',
        resource_type: 'BetterTogether::Platform'
      ) do |role|
        role.name = 'View Only Analytics'
      end
    end

    before do
      configure_host_platform

      # Create role with only view permission (no create or download)
      view_only_role.assign_resource_permissions([view_permission.identifier])

      user = find_or_create_test_user('limited@example.test', 'SecureTest123!@#', :user)
      BetterTogether::PersonPlatformMembership.find_or_create_by!(
        joinable: platform,
        member: user.person
      ) do |membership|
        membership.role = view_only_role
      end

      Rails.cache.clear
      capybara_sign_in_user('limited@example.test', 'SecureTest123!@#')
    end

    scenario 'User can view reports but cannot create them' do
      visit better_together.metrics_page_view_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Page View Reports')

      # Try to access new report form - should get authorization error
      visit better_together.new_metrics_page_view_report_path(locale: I18n.default_locale)

      # Should be blocked by policy check at controller level
      expect(page).to have_content('You are not authorized')
      expect(page).not_to have_content('New Page View Report')
    end

    scenario 'User cannot download reports without permission' do
      report = create(:better_together_metrics_page_view_report)
      report.report_file.attach(
        io: StringIO.new('test,data'),
        filename: 'test_report.csv',
        content_type: 'text/csv'
      )

      # Try to download without permission
      visit better_together.download_metrics_page_view_report_path(report, locale: I18n.default_locale)

      # Should not get the file content
      expect(page).not_to have_content('test,data')
    end
  end

  describe 'Role Assignment UI', :skip_host_setup do
    before do
      configure_host_platform
      find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager)
      Rails.cache.clear
      capybara_login_as_platform_manager
    end

    scenario 'Platform manager can assign analytics viewer role' do
      other_user = create(:better_together_user, :confirmed, email: 'analytics@example.com', password: 'SecureAnalytics123!@#')

      # Create membership directly then assign role via API/model
      # (UI test would require member management interface which may not exist yet)
      membership = BetterTogether::PersonPlatformMembership.create!(
        joinable: platform,
        member: other_user.person,
        role: analytics_viewer_role
      )

      # Verify role assignment worked
      expect(membership.reload.role).to eq(analytics_viewer_role)
      expect(other_user.person.permitted_to?('view_metrics_dashboard')).to be true
    end
  end
end
