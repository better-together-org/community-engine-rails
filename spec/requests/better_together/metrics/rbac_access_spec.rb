# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics RBAC Access Control', type: :request do
  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  # Find or create the analytics viewer role (it should exist from seeds/builder)
  let!(:analytics_viewer_role) do
    BetterTogether::Role.find_by(
      identifier: 'platform_analytics_viewer',
      resource_type: 'BetterTogether::Platform',
      resource_id: platform.id
    ) || BetterTogether::Role.create!(
      identifier: 'platform_analytics_viewer',
      resource_type: 'BetterTogether::Platform',
      resource_id: platform.id,
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
      it 'redirects to sign in' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to redirect_to(new_better_together_person_session_path(locale:))
      end
    end

    context 'when user lacks view_metrics_dashboard permission', :as_user do
      it 'returns forbidden' do
        send(method, send(path_helper, { locale: }.merge(params)))
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user has view_metrics_dashboard permission', :as_user do
      before do
        user = BetterTogether::Person.find_by(email: 'user@example.com')
        platform.members.find_or_create_by!(member: user) do |member|
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

  shared_examples 'requires create_metrics_reports permission' do |path_helper, create_params|
    context 'when user lacks create_metrics_reports permission', :as_user do
      before do
        # Give view permission but not create
        user = BetterTogether::Person.find_by(email: 'user@example.com')
        view_only_role = BetterTogether::Role.create!(
          identifier: 'view_only_analytics',
          resource_type: 'BetterTogether::Platform',
          resource_id: platform.id,
          name: 'View Only Analytics'
        )
        view_only_role.role_resource_permissions.create!(resource_permission: view_permission)
        platform.members.find_or_create_by!(member: user) do |member|
          member.role = view_only_role
        end
      end

      it 'returns forbidden' do
        post send(path_helper, locale:), params: create_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user has create_metrics_reports permission', :as_user do
      before do
        user = BetterTogether::Person.find_by(email: 'user@example.com')
        platform.members.find_or_create_by!(member: user) do |member|
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
    include_examples 'requires view_metrics_dashboard permission',
                     :get,
                     :better_together_host_dashboard_path
  end

  describe 'Metrics Reports Index' do
    include_examples 'requires view_metrics_dashboard permission',
                     :get,
                     :better_together_metrics_reports_path
  end

  describe 'Page View Reports' do
    describe 'GET /metrics/page_view_reports' do
      include_examples 'requires view_metrics_dashboard permission',
                       :get,
                       :better_together_metrics_page_view_reports_path
    end

    describe 'GET /metrics/page_view_reports/new' do
      include_examples 'requires view_metrics_dashboard permission',
                       :get,
                       :better_together_new_metrics_page_view_report_path
    end

    describe 'POST /metrics/page_view_reports' do
      include_examples 'requires create_metrics_reports permission',
                       :better_together_metrics_page_view_reports_path,
                       {
                         metrics_page_view_report: {
                           file_format: 'csv',
                           sort_by_total_views: false,
                           filters: { from_date: '', to_date: '', filter_pageable_type: '' }
                         }
                       }
    end

    describe 'GET /metrics/page_view_reports/:id' do
      let(:report) do
        create(:better_together_metrics_page_view_report, platform:)
      end

      context 'when user is not authenticated' do
        it 'redirects to sign in' do
          get better_together_metrics_page_view_report_path(locale:, id: report.id)
          expect(response).to redirect_to(new_better_together_person_session_path(locale:))
        end
      end

      context 'when user has view_metrics_dashboard permission', :as_user do
        before do
          user = BetterTogether::Person.find_by(email: 'user@example.com')
          platform.members.find_or_create_by!(member: user) do |member|
            member.role = analytics_viewer_role
          end
        end

        it 'allows access' do
          get better_together_metrics_page_view_report_path(locale:, id: report.id)
          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe 'DELETE /metrics/page_view_reports/:id' do
      let(:report) do
        create(:better_together_metrics_page_view_report, platform:)
      end

      context 'when user has create_metrics_reports permission', :as_user do
        before do
          user = BetterTogether::Person.find_by(email: 'user@example.com')
          platform.members.find_or_create_by!(member: user) do |member|
            member.role = analytics_viewer_role
          end
        end

        it 'allows report deletion' do
          delete better_together_metrics_page_view_report_path(locale:, id: report.id)
          expect(response).to have_http_status(:found)
        end
      end
    end
  end

  describe 'Link Click Reports' do
    describe 'GET /metrics/link_click_reports' do
      include_examples 'requires view_metrics_dashboard permission',
                       :get,
                       :better_together_metrics_link_click_reports_path
    end

    describe 'GET /metrics/link_click_reports/new' do
      include_examples 'requires view_metrics_dashboard permission',
                       :get,
                       :better_together_new_metrics_link_click_report_path
    end

    describe 'POST /metrics/link_click_reports' do
      include_examples 'requires create_metrics_reports permission',
                       :better_together_metrics_link_click_reports_path,
                       {
                         metrics_link_click_report: {
                           file_format: 'csv',
                           filters: { from_date: '', to_date: '' }
                         }
                       }
    end
  end

  describe 'Link Checker Reports' do
    describe 'GET /metrics/link_checker_reports' do
      include_examples 'requires view_metrics_dashboard permission',
                       :get,
                       :better_together_metrics_link_checker_reports_path
    end

    describe 'GET /metrics/link_checker_reports/new' do
      include_examples 'requires view_metrics_dashboard permission',
                       :get,
                       :better_together_new_metrics_link_checker_report_path
    end

    describe 'POST /metrics/link_checker_reports' do
      include_examples 'requires create_metrics_reports permission',
                       :better_together_metrics_link_checker_reports_path,
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
        create(:better_together_metrics_page_view_report, platform:)
      end

      before do
        # Give view and create but not download
        user = BetterTogether::Person.find_by(email: 'user@example.com')
        limited_role = BetterTogether::Role.create!(
          identifier: 'limited_analytics',
          resource_type: 'BetterTogether::Platform',
          resource_id: platform.id,
          name: 'Limited Analytics'
        )
        limited_role.role_resource_permissions.create!(resource_permission: view_permission)
        limited_role.role_resource_permissions.create!(resource_permission: create_permission)
        platform.members.find_or_create_by!(member: user) do |member|
          member.role = limited_role
        end

        # Generate the report file
        report.file.attach(
          io: StringIO.new('test,data'),
          filename: 'test_report.csv',
          content_type: 'text/csv'
        )
      end

      it 'returns forbidden for download action' do
        get better_together_download_metrics_page_view_report_path(locale:, id: report.id)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user has download_metrics_reports permission', :as_user do
      let(:report) do
        create(:better_together_metrics_page_view_report, platform:)
      end

      before do
        user = BetterTogether::Person.find_by(email: 'user@example.com')
        platform.members.find_or_create_by!(member: user) do |member|
          member.role = analytics_viewer_role
        end

        # Generate the report file
        report.file.attach(
          io: StringIO.new('test,data'),
          filename: 'test_report.csv',
          content_type: 'text/csv'
        )
      end

      it 'allows download' do
        get better_together_download_metrics_page_view_report_path(locale:, id: report.id)
        expect(response).to have_http_status(:found)
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
        nav_area = BetterTogether::NavigationArea.find_or_create_by!(identifier: 'platform_host')
        BetterTogether::NavigationItem.create!(
          navigation_area: nav_area,
          title: 'Analytics',
          icon: 'chart-line',
          route_name: 'metrics_reports',
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
        user = BetterTogether::Person.find_by(email: 'user@example.com')
        nav_item = BetterTogether::NavigationItem.find_by(permission_identifier: 'view_metrics_dashboard')

        expect(nav_item.visible_to?(user, platform:)).to be false
      end
    end

    context 'when user has view_metrics_dashboard permission', :as_user do
      before do
        user = BetterTogether::Person.find_by(email: 'user@example.com')
        platform.members.find_or_create_by!(member: user) do |member|
          member.role = analytics_viewer_role
        end
      end

      it 'shows Analytics nav item' do
        user = BetterTogether::Person.find_by(email: 'user@example.com')
        nav_item = BetterTogether::NavigationItem.find_by(permission_identifier: 'view_metrics_dashboard')

        expect(nav_item.visible_to?(user, platform:)).to be true
      end
    end
  end
end
