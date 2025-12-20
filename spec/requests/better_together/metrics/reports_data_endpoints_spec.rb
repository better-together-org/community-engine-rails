# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::Reports Data Endpoints', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:base_path) { "/#{locale}/host/metrics/reports" }

  describe 'GET /page_views_by_url_data' do
    let!(:old_view) { create(:metrics_page_view, page_url: 'https://example.com/old', viewed_at: 60.days.ago) }
    let!(:page1_view_early) { create(:metrics_page_view, page_url: 'https://example.com/page1', viewed_at: 10.days.ago) }
    let!(:page1_view_recent) { create(:metrics_page_view, page_url: 'https://example.com/page1', viewed_at: 5.days.ago) }
    let!(:page2_view) { create(:metrics_page_view, page_url: 'https://example.com/page2', viewed_at: 3.days.ago) }

    context 'with default date range (last 30 days)' do
      it 'returns filtered page views by URL' do
        get "#{base_path}/page_views_by_url_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels']).to include('https://example.com/page1', 'https://example.com/page2')
        expect(json['labels']).not_to include('https://example.com/old')
        expect(json['values']).to be_an(Array)
      end
    end

    context 'with custom date range' do
      it 'filters records within the specified range' do
        start_date = 15.days.ago.iso8601
        end_date = 2.days.ago.iso8601

        get "#{base_path}/page_views_by_url_data",
            params: { start_date: start_date, end_date: end_date },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels']).to include('https://example.com/page1', 'https://example.com/page2')
        expect(json['labels']).not_to include('https://example.com/old')
      end
    end

    context 'with invalid date range' do
      it 'returns error when start_date is after end_date' do
        get "#{base_path}/page_views_by_url_data",
            params: { start_date: Time.current.iso8601, end_date: 1.day.ago.iso8601 },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
      end

      it 'returns error when range exceeds 1 year' do
        get "#{base_path}/page_views_by_url_data",
            params: { start_date: 2.years.ago.iso8601, end_date: Time.current.iso8601 },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
      end
    end
  end

  describe 'GET /page_views_daily_data' do
    let!(:view_five_days_ago) { create(:metrics_page_view, viewed_at: 5.days.ago) }
    let!(:view_three_days_ago) { create(:metrics_page_view, viewed_at: 3.days.ago) }

    it 'returns daily page view counts' do
      get "#{base_path}/page_views_daily_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to be_an(Array)
      expect(json['values']).to be_an(Array)
      expect(json['labels'].length).to eq(json['values'].length)
    end
  end

  describe 'GET /link_clicks_by_url_data' do
    let!(:link1_click_early) { create(:metrics_link_click, url: 'https://example.com/link1', clicked_at: 10.days.ago) }
    let!(:link1_click_recent) { create(:metrics_link_click, url: 'https://example.com/link1', clicked_at: 5.days.ago) }
    let!(:recent_click2) { create(:metrics_link_click, url: 'https://example.com/link1', clicked_at: 5.days.ago) }

    it 'returns filtered link clicks by URL' do
      get "#{base_path}/link_clicks_by_url_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to include('https://example.com/link1')
      expect(json['labels']).not_to include('https://example.com/old')
    end
  end

  describe 'GET /link_clicks_daily_data' do
    let!(:click_five_days_ago) { create(:metrics_link_click, clicked_at: 5.days.ago) }
    let!(:click_three_days_ago) { create(:metrics_link_click, clicked_at: 3.days.ago) }

    it 'returns daily link click counts' do
      get "#{base_path}/link_clicks_daily_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to be_an(Array)
      expect(json['values']).to be_an(Array)
    end
  end

  describe 'GET /downloads_by_file_data' do
    let!(:old_download) { create(:metrics_download, file_name: 'old.pdf', downloaded_at: 60.days.ago) }
    let!(:recent_download) { create(:metrics_download, file_name: 'report.pdf', downloaded_at: 5.days.ago) }

    it 'returns filtered downloads by file name' do
      get "#{base_path}/downloads_by_file_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to include('report.pdf')
      expect(json['labels']).not_to include('old.pdf')
    end
  end

  describe 'GET /shares_by_platform_data' do
    let!(:old_share) { create(:metrics_share, platform: 'facebook', shared_at: 60.days.ago) }
    let!(:recent_share) { create(:metrics_share, platform: 'linkedin', shared_at: 5.days.ago) }

    it 'returns filtered shares by platform' do
      get "#{base_path}/shares_by_platform_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to include('linkedin')
      expect(json['labels']).not_to include('facebook')
    end
  end

  describe 'GET /shares_by_url_and_platform_data' do
    let!(:facebook_share) { create(:metrics_share, url: 'https://example.com/article', platform: 'facebook', shared_at: 5.days.ago) }
    let!(:linkedin_share) { create(:metrics_share, url: 'https://example.com/article', platform: 'linkedin', shared_at: 3.days.ago) }

    it 'returns shares grouped by URL and platform with datasets' do
      get "#{base_path}/shares_by_url_and_platform_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to be_an(Array)
      expect(json['datasets']).to be_an(Array)
      expect(json['datasets'].first).to have_key('label')
      expect(json['datasets'].first).to have_key('backgroundColor')
      expect(json['datasets'].first).to have_key('data')
    end
  end

  describe 'GET /links_by_host_data' do
    let!(:old_link) { create(:content_link, host: 'old.example.com', created_at: 60.days.ago) }
    let!(:recent_link) { create(:content_link, host: 'example.com', created_at: 5.days.ago) }

    it 'returns filtered links by host' do
      get "#{base_path}/links_by_host_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to be_an(Array)
      expect(json['values']).to be_an(Array)
    end
  end

  describe 'GET /invalid_by_host_data' do
    let!(:invalid_link) { create(:content_link, host: 'broken.com', valid_link: false, created_at: 5.days.ago) }

    it 'returns invalid links grouped by host' do
      get "#{base_path}/invalid_by_host_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to be_an(Array)
      expect(json['values']).to be_an(Array)
    end
  end

  describe 'GET /failures_daily_data' do
    let!(:failure) { create(:content_link, valid_link: false, last_checked_at: 5.days.ago) }

    it 'returns daily invalid link counts' do
      get "#{base_path}/failures_daily_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to be_an(Array)
      expect(json['values']).to be_an(Array)
    end
  end

  describe 'authorization' do
    context 'when user does not have view_metrics_dashboard permission' do
      before do
        # Remove the permission from the current user
        current_user = BetterTogether.user_class.find_by(email: 'platform_manager@example.com')
        current_user.role_resources.destroy_all
      end

      it 'denies access to data endpoints' do
        get "#{base_path}/page_views_by_url_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
