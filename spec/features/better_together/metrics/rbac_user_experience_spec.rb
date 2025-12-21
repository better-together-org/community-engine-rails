# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics RBAC User Experience', :js do
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

  # Find permissions
  let!(:view_permission) do
    BetterTogether::ResourcePermission.find_by(identifier: 'view_metrics_dashboard')
  end

  let!(:create_permission) do
    BetterTogether::ResourcePermission.find_by(identifier: 'create_metrics_reports')
  end

  let!(:download_permission) do
    BetterTogether::ResourcePermission.find_by(identifier: 'download_metrics_reports')
  end

  before do
    # Ensure permissions are assigned to the analytics viewer role
    [view_permission, create_permission, download_permission].compact.each do |permission|
      analytics_viewer_role.role_resource_permissions.find_or_create_by!(
        resource_permission: permission
      )
    end
  end

  describe 'Analytics Viewer Role', :as_user do
    before do
      user = find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
      BetterTogether::PersonPlatformMembership.create!(
        joinable: platform,
        member: user.person,
        role: analytics_viewer_role
      )
    end

    scenario 'User with analytics viewer role can access metrics reports' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Metrics Reports')
      expect(page).not_to have_content('Access Denied')
    end

    scenario 'User can see Analytics navigation item' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      # Analytics nav item should be visible with permission
      within('nav') do
        expect(page).to have_link('Analytics', href: better_together.metrics_reports_path(locale: I18n.default_locale))
      end
    end

    scenario 'User can view metrics reports list' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Metrics Reports')
      expect(page).not_to have_content('Access Denied')
    end

    scenario 'User can access page view reports' do
      visit better_together.metrics_page_view_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Page View Reports')
      expect(page).to have_link('Generate New Report')
    end

    scenario 'User can create a page view report' do
      visit better_together.new_metrics_page_view_report_path(locale: I18n.default_locale)

      expect(page).to have_content('Generate Page View Report')

      # Fill out the form
      select 'CSV', from: 'File Format'
      click_button 'Generate Report'

      expect(page).to have_content('Report generation started')
    end

    scenario 'User can access link click reports' do
      visit better_together.metrics_link_click_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Link Click Reports')
      expect(page).to have_link('Generate New Report')
    end

    scenario 'User can access link checker reports' do
      visit better_together.metrics_link_checker_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Link Checker Reports')
      expect(page).to have_link('Generate New Report')
    end

    scenario 'User can download generated reports' do
      # Create a report with attached file
      report = create(:better_together_metrics_page_view_report, platform:)
      report.file.attach(
        io: StringIO.new('test,data'),
        filename: 'test_report.csv',
        content_type: 'text/csv'
      )

      visit better_together.metrics_page_view_report_path(report, locale: I18n.default_locale)

      expect(page).to have_link('Download Report')

      # Click download should redirect to file
      click_link 'Download Report'
      # Download initiates (we can't easily test file content in feature specs)
    end
  end

  describe 'Regular User Without Analytics Permission', :as_user do
    scenario 'User cannot see Analytics navigation item' do
      visit better_together.host_dashboard_path(locale: I18n.default_locale)

      within('nav') do
        expect(page).not_to have_link('Analytics')
      end
    end

    scenario 'User cannot access metrics dashboard directly' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Access Denied')
    end

    scenario 'User cannot access metrics reports list' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Access Denied')
    end

    scenario 'User cannot access page view reports' do
      visit better_together.metrics_page_view_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Access Denied')
    end

    scenario 'User cannot create reports' do
      visit better_together.new_metrics_page_view_report_path(locale: I18n.default_locale)

      expect(page).to have_content('Access Denied')
    end

    scenario 'User cannot download reports' do
      report = create(:better_together_metrics_page_view_report, platform:)
      report.file.attach(
        io: StringIO.new('test,data'),
        filename: 'test_report.csv',
        content_type: 'text/csv'
      )

      visit better_together.download_metrics_page_view_report_path(report, locale: I18n.default_locale)

      expect(page).to have_content('Access Denied')
    end
  end

  describe 'Platform Manager', :as_platform_manager do
    scenario 'Platform manager can access all metrics features' do
      visit better_together.host_dashboard_path(locale: I18n.default_locale)

      expect(page).to have_content('Platform Dashboard')

      # Should see Analytics nav item
      within('nav') do
        expect(page).to have_link('Analytics')
      end

      # Can access metrics reports
      visit better_together.metrics_reports_path(locale: I18n.default_locale)
      expect(page).to have_content('Metrics Reports')

      # Can create reports
      visit better_together.new_metrics_page_view_report_path(locale: I18n.default_locale)
      expect(page).to have_content('Generate Page View Report')
    end
  end

  describe 'Unauthenticated User' do
    scenario 'Redirects to sign in when accessing metrics' do
      visit better_together.metrics_reports_path(locale: I18n.default_locale)

      expect(page).to have_current_path(better_together.new_person_session_path(locale: I18n.default_locale))
      expect(page).to have_content('Sign in')
    end

    scenario 'Redirects to sign in when accessing host dashboard' do
      visit better_together.host_dashboard_path(locale: I18n.default_locale)

      expect(page).to have_current_path(better_together.new_person_session_path(locale: I18n.default_locale))
      expect(page).to have_content('Sign in')
    end
  end

  describe 'Limited Analytics Access' do
    let(:view_only_role) do
      BetterTogether::Role.create!(
        identifier: 'view_only_analytics',
        resource_type: 'BetterTogether::Platform',
        name: 'View Only Analytics'
      )
    end

    before do
      # Create role with only view permission (no create or download)
      view_only_role.role_resource_permissions.create!(resource_permission: view_permission)

      user = BetterTogether::User.find_by(email: 'user@example.test')
      BetterTogether::PersonPlatformMembership.create!(
        joinable: platform,
        member: user.person,
        role: view_only_role
      )
    end

    scenario 'User can view reports but cannot create them', :as_user do
      visit better_together.metrics_page_view_reports_path(locale: I18n.default_locale)

      expect(page).to have_content('Page View Reports')

      # Try to access new report form
      visit better_together.new_metrics_page_view_report_path(locale: I18n.default_locale)

      # Should see form but get error on submit
      expect(page).to have_content('Generate Page View Report')

      select 'CSV', from: 'File Format'
      click_button 'Generate Report'

      expect(page).to have_content('Access Denied')
    end

    scenario 'User cannot download reports without permission', :as_user do
      report = create(:better_together_metrics_page_view_report, platform:)
      report.file.attach(
        io: StringIO.new('test,data'),
        filename: 'test_report.csv',
        content_type: 'text/csv'
      )

      visit better_together.metrics_page_view_report_path(report, locale: I18n.default_locale)

      # Try to download
      visit better_together.download_metrics_page_view_report_path(report, locale: I18n.default_locale)

      expect(page).to have_content('Access Denied')
    end
  end

  describe 'Role Assignment UI' do
    scenario 'Platform manager can assign analytics viewer role', :as_platform_manager do
      other_user = create(:better_together_user, :confirmed, email: 'analytics@example.com', password: 'password123')

      # Visit platform members management (assumes this exists)
      visit better_together.host_dashboard_path(locale: I18n.default_locale)

      # Navigate to members section
      click_link 'Members' if page.has_link?('Members')

      # Find the user and assign role
      within("tr[data-person-id='#{other_user.id}']") do
        select 'Analytics Viewer', from: 'Role'
        click_button 'Update Role'
      end

      expect(page).to have_content('Role updated successfully')

      # Verify role assignment
      membership = BetterTogether::PersonPlatformMembership.find_by(joinable: platform, member: other_user.person)
      expect(membership.role).to eq(analytics_viewer_role)
    end
  end
end
