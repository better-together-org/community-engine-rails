# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::MetricsSummary', :no_auth do
  let(:manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:manager_token) { api_sign_in_and_get_token(manager_user) }
  let(:manager_headers) { api_auth_headers(manager_user, token: manager_token) }

  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:regular_token) { api_sign_in_and_get_token(regular_user) }
  let(:regular_headers) { api_auth_headers(regular_user, token: regular_token) }

  let(:jsonapi_headers) { { 'Content-Type' => 'application/vnd.api+json', 'Accept' => 'application/vnd.api+json' } }
  let(:url) { '/api/v1/metrics/summary' }

  describe 'GET /api/v1/metrics/summary' do
    context 'when authenticated as platform manager' do
      before do
        # Create some page views for metrics
        3.times do |i|
          BetterTogether::Metrics::PageView.create!(
            page_url: "/page-#{i}",
            locale: 'en',
            viewed_at: Time.current
          )
        end

        get url, headers: manager_headers
      end

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns metrics summary data' do
        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']['type']).to eq('metrics_summary')
      end

      it 'includes page view counts' do
        json = JSON.parse(response.body)
        attrs = json['data']['attributes']

        expect(attrs).to have_key('total_page_views')
        expect(attrs['total_page_views']).to be >= 3
      end

      it 'includes unique pages count' do
        json = JSON.parse(response.body)
        attrs = json['data']['attributes']

        expect(attrs).to have_key('unique_pages')
        expect(attrs['unique_pages']).to be >= 3
      end

      it 'includes views by locale' do
        json = JSON.parse(response.body)
        attrs = json['data']['attributes']

        expect(attrs).to have_key('views_by_locale')
        expect(attrs['views_by_locale']).to be_a(Hash)
      end

      it 'includes top pages' do
        json = JSON.parse(response.body)
        attrs = json['data']['attributes']

        expect(attrs).to have_key('top_pages')
        expect(attrs['top_pages']).to be_a(Hash)
      end
    end

    context 'when authenticated as regular user' do
      before { get url, headers: regular_headers }

      it 'returns not found status' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do
      before { get url, headers: jsonapi_headers }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with date range filter' do
      before do
        BetterTogether::Metrics::PageView.create!(
          page_url: '/recent-page',
          locale: 'en',
          viewed_at: 1.day.ago
        )
        BetterTogether::Metrics::PageView.create!(
          page_url: '/old-page',
          locale: 'en',
          viewed_at: 30.days.ago
        )

        get "#{url}?from_date=#{7.days.ago.to_date}&to_date=#{Date.current}", headers: manager_headers
      end

      it 'returns filtered metrics' do
        json = JSON.parse(response.body)
        attrs = json['data']['attributes']

        expect(attrs['total_page_views']).to be >= 1
      end
    end
  end
end
