# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics RBAC Access Control' do
  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  # Find or create the analytics viewer role (it should exist from seeds/builder)
  let!(:analytics_viewer_role) do
    BetterTogether::Role.find_by(
      identifier: 'platform_analytics_viewer',
      resource_type: 'BetterTogether::Platform'
    ) || BetterTogether::Role.create!(
      identifier: 'platform_analytics_viewer',
      resource_type: 'BetterTogether::Platform',
      name: 'Analytics Viewer',
      description: 'Can view and generate analytics reports'
    )
  end

  # Find permissions (they should exist from seeds/builder)
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

  shared_examples 'requires view_metrics_dashboard permission' do |method, path_helper, params = {}|
    context 'when user is not authenticated' do
      it 'returns 404 (route within authenticated constraint)' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user lacks view_metrics_dashboard permission', :as_user do
      it 'returns 404 (route requires permission in constraint)' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user has view_metrics_dashboard permission', :as_user do
      before do
        user = BetterTogether::User.find_by(email: 'user@example.test').person
        platform.person_platform_memberships.find_or_create_by!(member: user) do |member|
          member.role = analytics_viewer_role
        end
      end

      it 'allows access' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when user is platform manager', :as_platform_manager do
      it 'allows access' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to have_http_status(:ok)
      end
    end
  end

  shared_examples 'requires manage_platform permission' do |method, path_helper, params = {}|
    context 'when user is not authenticated' do
      it 'returns 404 (route within authenticated constraint)' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user lacks manage_platform permission', :as_user do
      it 'returns 404 (route requires permission in constraint)' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user has view_metrics_dashboard permission', :as_user do
      before do
        user = BetterTogether::User.find_by(email: 'user@example.test').person
        platform.person_platform_memberships.find_or_create_by!(member: user) do |member|
          member.role = analytics_viewer_role
        end
      end

      it 'returns 404 (route requires manage_platform permission)' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is platform manager', :as_platform_manager do
      it 'allows access' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to have_http_status(:ok)
      end
    end
  end

  shared_examples 'requires create_metrics_reports permission' do |path_helper, create_params|
    context 'when user lacks create_metrics_reports permission', :as_user do
      before do
        # Give view permission but not create
        user = BetterTogether::User.find_by(email: 'user@example.test').person
        view_only_role = BetterTogether::Role.find_or_create_by!(
          identifier: "view_only_analytics_#{SecureRandom.hex(4)}",
          resource_type: 'BetterTogether::Platform'
        ) do |role|
          role.name = 'View Only Analytics'
        end
        view_only_role.role_resource_permissions.find_or_create_by!(resource_permission: view_permission)
        platform.person_platform_memberships.find_or_create_by!(member: user) do |member|
          member.role = view_only_role
        end
      end

      it 'redirects due to lack of permission' do
        post send(path_helper, locale:), params: create_params
        expect(response).to have_http_status(:found)
      end
    end

    context 'when user has create_metrics_reports permission', :as_user do
      before do
        user = BetterTogether::User.find_by(email: 'user@example.test').person
        platform.person_platform_memberships.find_or_create_by!(member: user) do |member|
          member.role = analytics_viewer_role
        end
      end

      it 'allows report creation' do
        post send(path_helper, locale:), params: create_params
        expect(response).to have_http_status(:found)
      end
    end
  end

  describe 'Host Dashboard Access' do
    it_behaves_like 'requires manage_platform permission',
                    :get,
                    :host_dashboard_path
  end

  describe 'Metrics Reports Index' do
    it_behaves_like 'requires view_metrics_dashboard permission',
                    :get,
                    :metrics_reports_path
  end

  describe 'Page View Reports' do
    describe 'GET /metrics/page_view_reports' do
      it_behaves_like 'requires view_metrics_dashboard permission',
                      :get,
                      :metrics_page_view_reports_path
    end

    describe 'GET /metrics/page_view_reports/new' do
      it_behaves_like 'requires view_metrics_dashboard permission',
                      :get,
                      :new_metrics_page_view_report_path
    end

    describe 'POST /metrics/page_view_reports' do
      it_behaves_like 'requires create_metrics_reports permission',
                      :metrics_page_view_reports_path,
                      {
                        metrics_page_view_report: {
                          file_format: 'csv',
                          sort_by_total_views: false,
                          filters: { from_date: '', to_date: '', filter_pageable_type: '' }
                        }
                      }
    end

    # NOTE: Page view reports only have index, new, create, and download actions
    # No show or destroy actions are implemented
  end

  describe 'Link Click Reports' do
    describe 'GET /metrics/link_click_reports' do
      it_behaves_like 'requires view_metrics_dashboard permission',
                      :get,
                      :metrics_link_click_reports_path
    end

    describe 'GET /metrics/link_click_reports/new' do
      it_behaves_like 'requires view_metrics_dashboard permission',
                      :get,
                      :new_metrics_link_click_report_path
    end

    describe 'POST /metrics/link_click_reports' do
      it_behaves_like 'requires create_metrics_reports permission',
                      :metrics_link_click_reports_path,
                      {
                        metrics_link_click_report: {
                          file_format: 'csv',
                          sort_by_total_clicks: false,
                          filters: { from_date: '', to_date: '' }
                        }
                      }
    end
  end

  describe 'Link Checker Reports' do
    describe 'GET /metrics/link_checker_reports' do
      it_behaves_like 'requires view_metrics_dashboard permission',
                      :get,
                      :metrics_link_checker_reports_path
    end

    describe 'GET /metrics/link_checker_reports/new' do
      it_behaves_like 'requires view_metrics_dashboard permission',
                      :get,
                      :new_metrics_link_checker_report_path
    end

    describe 'POST /metrics/link_checker_reports' do
      it_behaves_like 'requires create_metrics_reports permission',
                      :metrics_link_checker_reports_path,
                      {
                        metrics_link_checker_report: {
                          file_format: 'csv'
                        }
                      }
    end
  end

  describe 'Download Permission' do
    context 'when user lacks download_metrics_reports permission', :as_user do
      let(:report) do
        create(:metrics_page_view_report)
      end

      before do
        # Give view and create but not download
        user = BetterTogether::User.find_by(email: 'user@example.test').person
        limited_role = BetterTogether::Role.find_or_create_by!(
          identifier: "limited_analytics_#{SecureRandom.hex(4)}",
          resource_type: 'BetterTogether::Platform'
        ) do |role|
          role.name = 'Limited Analytics'
        end
        limited_role.role_resource_permissions.find_or_create_by!(resource_permission: view_permission)
        limited_role.role_resource_permissions.find_or_create_by!(resource_permission: create_permission)
        platform.person_platform_memberships.find_or_create_by!(member: user) do |member|
          member.role = limited_role
        end

        # Generate the report file
        report.report_file.attach(
          io: StringIO.new('test,data'),
          filename: 'test_report.csv',
          content_type: 'text/csv'
        )
      end

      it 'redirects due to authorization failure' do
        get download_metrics_page_view_report_path(locale:, id: report.id)
        expect(response).to have_http_status(:found)
      end
    end

    context 'when user has download_metrics_reports permission', :as_user do
      let(:report) do
        create(:metrics_page_view_report)
      end

      before do
        user = BetterTogether::User.find_by(email: 'user@example.test').person
        platform.person_platform_memberships.find_or_create_by!(member: user) do |member|
          member.role = analytics_viewer_role
        end

        # Generate the report file
        report.report_file.attach(
          io: StringIO.new('test,data'),
          filename: 'test_report.csv',
          content_type: 'text/csv'
        )
      end

      it 'allows download' do
        get download_metrics_page_view_report_path(locale:, id: report.id)
        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Disposition']).to include('attachment')
      end
    end
  end

  describe 'Navigation Item Visibility' do
    let(:analytics_nav_item) do
      BetterTogether::NavigationItem.find_by(
        permission_identifier: 'view_metrics_dashboard',
        visibility_strategy: 'permission'
      )
    end

    before do
      # Ensure Analytics nav item exists with permission-based visibility
      unless analytics_nav_item
        nav_area = BetterTogether::NavigationArea.find_or_create_by!(identifier: 'platform_host_analytics_test') do |area|
          area.name = 'Platform Host Analytics Test'
        end
        BetterTogether::NavigationItem.create!(
          navigation_area: nav_area,
          title: 'Analytics',
          icon: 'chart-line',
          item_type: 'link',
          route_name: 'metrics_reports_url',
          position: 1,
          visible: true,
          privacy: 'private',
          visibility_strategy: 'permission',
          permission_identifier: 'view_metrics_dashboard'
        )
      end
    end

    context 'when user lacks view_metrics_dashboard permission', :as_user do
      it 'hides Analytics nav item' do
        user = BetterTogether::User.find_by(email: 'user@example.test').person
        nav_item = BetterTogether::NavigationItem.find_by(permission_identifier: 'view_metrics_dashboard')

        expect(nav_item.visible_to?(user, platform:)).to be false
      end
    end

    context 'when user has view_metrics_dashboard permission', :as_user do
      before do
        user = BetterTogether::User.find_by(email: 'user@example.test').person
        platform.person_platform_memberships.find_or_create_by!(member: user) do |member|
          member.role = analytics_viewer_role
        end
      end

      it 'shows Analytics nav item' do
        user = BetterTogether::User.find_by(email: 'user@example.test').person
        nav_item = BetterTogether::NavigationItem.find_by(permission_identifier: 'view_metrics_dashboard')

        expect(nav_item.visible_to?(user, platform:)).to be true
      end
    end
  end
end
