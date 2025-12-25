# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics RBAC Authorization' do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  # Find the analytics viewer role (should exist from seeds)
  let!(:analytics_viewer_role) do
    BetterTogether::Role.find_by!(identifier: 'platform_analytics_viewer')
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
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
  end

  describe 'Analytics Viewer Role' do
    before do
      # Create user with role
      user = find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
      BetterTogether::PersonPlatformMembership.find_or_create_by!(
        joinable: platform,
        member: user.person
      ) do |membership|
        membership.role = analytics_viewer_role
      end

      Rails.cache.clear
      login('user@example.test', 'SecureTest123!@#')
    end

    describe 'Access Control' do
      it 'allows access to metrics reports' do
        get better_together.metrics_reports_path(locale: locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Metrics Reports')
        expect(response.body).not_to include('You are not authorized')
      end

      it 'allows access to page view reports' do
        get better_together.metrics_page_view_reports_path(locale: locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Page View Reports')
      end

      it 'allows access to new report form' do
        get better_together.new_metrics_page_view_report_path(locale: locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Page View Report')
      end

      it 'allows downloading reports' do
        report = create(:better_together_metrics_page_view_report)
        report.report_file.attach(
          io: StringIO.new('test,data'),
          filename: 'test_report.csv',
          content_type: 'text/csv'
        )

        get better_together.download_metrics_page_view_report_path(report, locale: locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('test,data')
      end
    end

    describe 'Content Verification' do
      it 'includes analytics navigation elements' do
        get better_together.metrics_reports_path(locale: locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-identifier="analytics"')
        expect(response.body).to include('Analytics')
      end

      it 'includes new report link in page view reports' do
        get better_together.metrics_page_view_reports_path(locale: locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Report')
      end
    end
  end

  describe 'Unauthorized User', :skip_host_setup do
    before do
      configure_host_platform

      # Create user without special permissions
      find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
      login('user@example.test', 'SecureTest123!@#')
    end

    describe 'Access Denial' do
      it 'denies access to metrics dashboard' do
        get better_together.metrics_reports_path(locale: locale)

        expect(response).not_to have_http_status(:success)
        expect(response.body).not_to include('Metrics Reports')
      end

      it 'denies access to page view reports' do
        get better_together.metrics_page_view_reports_path(locale: locale)

        expect(response).not_to have_http_status(:success)
        expect(response.body).not_to include('Page View Reports')
      end

      it 'denies access to create reports' do
        get better_together.new_metrics_page_view_report_path(locale: locale)

        expect(response).not_to have_http_status(:success)
        expect(response.body).not_to include('Generate Page View Report')
      end

      it 'denies downloading reports' do
        report = create(:better_together_metrics_page_view_report)
        report.report_file.attach(
          io: StringIO.new('test,data'),
          filename: 'test_report.csv',
          content_type: 'text/csv'
        )

        get better_together.download_metrics_page_view_report_path(report, locale: locale)

        expect(response).not_to have_http_status(:success)
        expect(response.body).not_to include('test,data')
      end
    end
  end

  describe 'Platform Manager', :as_platform_manager do
    describe 'Full Access' do
      it 'has access to all metrics features' do
        paths = [
          better_together.metrics_reports_path(locale: locale),
          better_together.metrics_page_view_reports_path(locale: locale),
          better_together.new_metrics_page_view_report_path(locale: locale)
        ]

        paths.each do |path|
          get path
          expect(response).to have_http_status(:success)
        end
      end

      it 'can download reports' do
        report = create(:better_together_metrics_page_view_report)
        report.report_file.attach(
          io: StringIO.new('test,data'),
          filename: 'test_report.csv',
          content_type: 'text/csv'
        )

        get better_together.download_metrics_page_view_report_path(report, locale: locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('test,data')
      end
    end
  end
end
