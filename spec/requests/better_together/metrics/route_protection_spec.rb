# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics Route Protection' do
  let(:locale) { I18n.default_locale }

  describe 'Unauthenticated Route Access' do
    it 'blocks access to new page view report form' do
      get better_together.new_metrics_page_view_report_path(locale: locale)
      expect(response).to have_http_status(:not_found)
    end

    it 'blocks access to page view reports index' do
      get better_together.metrics_page_view_reports_path(locale: locale)
      expect(response).to have_http_status(:not_found)
    end

    it 'blocks access to metrics reports index' do
      get better_together.metrics_reports_path(locale: locale)
      expect(response).to have_http_status(:not_found)
    end

    it 'blocks access to link click reports' do
      get better_together.metrics_link_click_reports_path(locale: locale)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'Analytics Viewer Route Access' do
    before do
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

    it 'allows access to new page view report form' do
      get better_together.new_metrics_page_view_report_path(locale: locale)
      expect(response).to have_http_status(:success)
      expect_html_content('Page View Report')
    end

    it 'allows access to page view reports index' do
      get better_together.metrics_page_view_reports_path(locale: locale)
      expect(response).to have_http_status(:success)
      expect_html_content('Page View Reports')
    end

    it 'allows access to metrics reports dashboard' do
      get better_together.metrics_reports_path(locale: locale)
      expect(response).to have_http_status(:success)
      expect_html_content('Metrics Reports')
    end
  end

  describe 'Platform Manager Route Access' do
    before do
      login('manager@example.test', 'SecureTest123!@#')
    end

    it 'allows full access to all metrics routes' do
      routes = [
        better_together.metrics_reports_path(locale: locale),
        better_together.metrics_page_view_reports_path(locale: locale),
        better_together.new_metrics_page_view_report_path(locale: locale),
        better_together.metrics_link_click_reports_path(locale: locale)
      ]

      routes.each do |route|
        get route
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'Navigation Visibility Testing' do
    before do
      login('manager@example.test', 'SecureTest123!@#')
    end

    it 'includes analytics navigation elements for authorized users' do
      get better_together.metrics_reports_path(locale: locale)

      expect(response).to have_http_status(:success)
      expect_html_content('Metrics')
    end

    it 'includes navigation links in metrics pages' do
      get better_together.metrics_page_view_reports_path(locale: locale)

      expect(response).to have_http_status(:success)
      expect_html_content('Reports')
    end
  end
end
