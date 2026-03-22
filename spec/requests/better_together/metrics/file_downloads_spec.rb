# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics File Downloads' do
  let(:locale) { I18n.default_locale }

  describe 'Analytics Viewer File Downloads' do
    before do
      # Create analytics viewer user
      analytics_viewer_user = create(:better_together_user, :confirmed,
                                     email: 'analytics@example.test',
                                     password: 'SecureTest123!@#')

      analytics_viewer_role = BetterTogether::Role.find_by!(identifier: 'platform_analytics_viewer')
      platform = BetterTogether::Platform.find_by(host: true)

      BetterTogether::PersonPlatformMembership.create!(
        joinable: platform,
        member: analytics_viewer_user.person,
        role: analytics_viewer_role
      )

      login('analytics@example.test', 'SecureTest123!@#')
    end

    it 'allows downloading generated reports with CSV content' do
      report = create(:better_together_metrics_page_view_report)
      report.report_file.attach(
        io: StringIO.new('test,data'),
        filename: 'test_report.csv',
        content_type: 'text/csv'
      )

      get better_together.download_metrics_page_view_report_path(report, locale: locale)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('test,data')
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end

    it 'handles file downloads without authorization errors' do
      report = create(:better_together_metrics_page_view_report)
      report.report_file.attach(
        io: StringIO.new('user,views\ntest,123'),
        filename: 'analytics_report.csv',
        content_type: 'text/csv'
      )

      get better_together.download_metrics_page_view_report_path(report, locale: locale)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('user,views')
    end
  end

  describe 'Unauthenticated File Download Access' do
    it 'denies access to report downloads' do
      report = create(:better_together_metrics_page_view_report)
      report.report_file.attach(
        io: StringIO.new('protected,data'),
        filename: 'protected_report.csv',
        content_type: 'text/csv'
      )

      get better_together.download_metrics_page_view_report_path(report, locale: locale)

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('protected,data')
    end
  end

  describe 'Platform Manager File Downloads' do
    before do
      login('manager@example.test', 'SecureTest123!@#')
    end

    it 'allows full download access' do
      report = create(:better_together_metrics_page_view_report)
      report.report_file.attach(
        io: StringIO.new('manager,access,data'),
        filename: 'manager_report.csv',
        content_type: 'text/csv'
      )

      get better_together.download_metrics_page_view_report_path(report, locale: locale)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('manager,access,data')
    end
  end
end
