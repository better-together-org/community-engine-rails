# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::Reports Data Endpoints', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:base_path) { "/#{locale}/host/metrics/reports" }

  describe 'GET /page_views_by_url_data' do
    context 'with default date range (last 30 days)' do
      it 'returns filtered page views by URL' do
        # Create test data with actual Page associations so they appear in datasets
        page1 = create(:page, slug: 'page1')
        page2 = create(:page, slug: 'page2')
        old_page = create(:page, slug: 'old')

        create(:metrics_page_view, pageable: old_page, viewed_at: 60.days.ago)
        create(:metrics_page_view, pageable: page1, viewed_at: 20.days.ago)
        create(:metrics_page_view, pageable: page1, viewed_at: 10.days.ago)
        create(:metrics_page_view, pageable: page2, viewed_at: 15.days.ago)

        get "#{base_path}/page_views_by_url_data", headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # URLs will be in the format /en/page1, /en/page2 due to routing
        expect(json['labels'].any? { |l| l.include?('page1') }).to be true
        expect(json['labels'].any? { |l| l.include?('page2') }).to be true
        expect(json['labels'].none? { |l| l.include?('old') }).to be true
        expect(json['datasets']).to be_an(Array)
        expect(json['datasets'].first).to have_key('label')
        expect(json['datasets'].first).to have_key('data')
      end
    end

    context 'with custom date range' do
      it 'filters records within the specified range' do
        # Create test data inline
        create(:metrics_page_view, page_url: '/old', viewed_at: 60.days.ago)
        create(:metrics_page_view, page_url: '/page1', viewed_at: 20.days.ago)
        create(:metrics_page_view, page_url: '/page1', viewed_at: 10.days.ago)
        create(:metrics_page_view, page_url: '/page2', viewed_at: 5.days.ago)

        start_date = 25.days.ago.iso8601
        end_date = 8.days.ago.iso8601

        get "#{base_path}/page_views_by_url_data",
            params: { start_date: start_date, end_date: end_date },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Only page1 (20 and 10 days ago) should be in range
        # old (60 days) and page2 (5 days) are outside the range
        expect(json['labels']).to include('/page1')
        expect(json['labels']).not_to include('/old', '/page2')
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
    let!(:view_five_days_ago) { create(:metrics_page_view, :with_page, viewed_at: 5.days.ago) }
    let!(:view_three_days_ago) { create(:metrics_page_view, :with_page, viewed_at: 3.days.ago) }

    it 'returns daily page view counts' do
      get "#{base_path}/page_views_daily_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to be_an(Array)
      expect(json['datasets']).to be_an(Array)
      expect(json['datasets'].first).to have_key('label')
      expect(json['datasets'].first).to have_key('data')
      expect(json['labels'].length).to eq(json['datasets'].first['data'].length)
    end
  end

  describe 'GET /link_clicks_by_url_data' do
    it 'returns filtered link clicks by URL' do
      # Create test data inline
      create(:metrics_link_click, url: 'https://example.com/link1', clicked_at: 10.days.ago)
      create(:metrics_link_click, url: 'https://example.com/link1', clicked_at: 5.days.ago)
      create(:metrics_link_click, url: 'https://example.com/link2', clicked_at: 15.days.ago)

      get "#{base_path}/link_clicks_by_url_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to include('https://example.com/link1', 'https://example.com/link2')
      expect(json['values']).to be_an(Array)
    end
  end

  describe 'GET /link_clicks_daily_data' do
    it 'returns daily link click counts' do
      # Create test data inline
      create(:metrics_link_click, clicked_at: 5.days.ago)
      create(:metrics_link_click, clicked_at: 3.days.ago)

      get "#{base_path}/link_clicks_daily_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to be_an(Array)
      expect(json['values']).to be_an(Array)
    end
  end

  describe 'GET /downloads_by_file_data' do
    it 'returns filtered downloads by file name' do
      # Create test data inline
      create(:metrics_download, file_name: 'old.pdf', file_type: 'pdf', downloaded_at: 60.days.ago)
      create(:metrics_download, file_name: 'report.pdf', file_type: 'pdf', downloaded_at: 5.days.ago)

      get "#{base_path}/downloads_by_file_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Within default 30-day range, should include recent download
      expect(json['labels']).to include('report.pdf')
      expect(json['labels']).not_to include('old.pdf')
      expect(json['values'].sum).to be >= 1
    end
  end

  describe 'GET /shares_by_platform_data' do
    let!(:old_share) { create(:metrics_share, platform: 'facebook', shared_at: 60.days.ago) }
    let!(:recent_share) { create(:metrics_share, platform: 'linkedin', shared_at: 5.days.ago) }

    it 'returns filtered shares by platform with datasets structure' do
      get "#{base_path}/shares_by_platform_data", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json['labels']).to include('linkedin')
      expect(json['labels']).not_to include('facebook')
      expect(json['datasets']).to be_an(Array)
      expect(json['datasets'].first).to have_key('label')
      expect(json['datasets'].first).to have_key('backgroundColor')
      expect(json['datasets'].first).to have_key('borderColor')
      expect(json['datasets'].first).to have_key('data')
      expect(json['datasets'].first['label']).to eq('Shares by Platform')
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

  describe 'additional filters' do
    describe 'locale filter' do
      it 'filters page views by locale' do
        # Create Pages with specific slugs for locale testing
        page_en = create(:page, slug: 'page-en')
        page_es = create(:page, slug: 'page-es')
        page_fr = create(:page, slug: 'page-fr')

        # Create page views with the associated Pages
        create(:metrics_page_view, pageable: page_en, locale: 'en', viewed_at: 10.days.ago)
        create(:metrics_page_view, pageable: page_es, locale: 'es', viewed_at: 10.days.ago)
        create(:metrics_page_view, pageable: page_fr, locale: 'fr', viewed_at: 10.days.ago)

        get "#{base_path}/page_views_by_url_data",
            params: { filter_locale: 'es' },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should only include the Spanish page (URL will be /es/page-es)
        expect(json['labels'].any? { |l| l.include?('page-es') }).to be true
        expect(json['labels'].none? { |l| l.include?('page-en') || l.include?('page-fr') }).to be true
        total_count = json['datasets'].flat_map { |d| d['data'] }.sum
        expect(total_count).to eq(1)
      end

      it 'returns all locales when no locale filter is specified' do
        # Create Pages with specific slugs for locale testing
        page_en = create(:page, slug: 'page-en')
        page_es = create(:page, slug: 'page-es')
        page_fr = create(:page, slug: 'page-fr')

        # Create page views with the associated Pages
        create(:metrics_page_view, pageable: page_en, locale: 'en', viewed_at: 10.days.ago)
        create(:metrics_page_view, pageable: page_es, locale: 'es', viewed_at: 10.days.ago)
        create(:metrics_page_view, pageable: page_fr, locale: 'fr', viewed_at: 10.days.ago)

        get "#{base_path}/page_views_by_url_data",
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should count all three views (grouped by URL)
        expect(json['labels'].any? { |l| l.include?('page-en') }).to be true
        expect(json['labels'].any? { |l| l.include?('page-es') }).to be true
        expect(json['labels'].any? { |l| l.include?('page-fr') }).to be true
        total_count = json['datasets'].flat_map { |d| d['data'] }.sum
        expect(total_count).to eq(3)
      end
    end

    describe 'pageable_type filter' do
      it 'filters page views by pageable_type' do
        # Create test data inline
        page = create(:page, slug: 'content-page')
        community = create(:community, slug: 'test-community')
        # Use the actual generated page paths
        page_path = "/#{locale}/#{page.slug}"
        community_path = "/#{locale}/communities/#{community.slug}"

        create(:metrics_page_view, pageable: page, page_url: page_path, viewed_at: 10.days.ago)
        create(:metrics_page_view, pageable: community, page_url: community_path, viewed_at: 10.days.ago)

        get "#{base_path}/page_views_by_url_data",
            params: { pageable_type: 'BetterTogether::Page' },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels']).to include(page_path)
        expect(json['labels']).not_to include(community_path)
        total_count = json['datasets'].flat_map { |d| d['data'] }.sum
        expect(total_count).to eq(1)
      end

      it 'returns all types when no pageable_type filter is specified' do
        # Create test data inline
        page = create(:page, slug: 'content-page')
        community = create(:community, slug: 'test-community')
        # Use the actual generated page paths
        page_path = "/#{locale}/#{page.slug}"
        community_path = "/#{locale}/communities/#{community.slug}"

        create(:metrics_page_view, pageable: page, page_url: page_path, viewed_at: 10.days.ago)
        create(:metrics_page_view, pageable: community, page_url: community_path, viewed_at: 10.days.ago)

        get "#{base_path}/page_views_by_url_data",
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels']).to include(page_path, community_path)
        total_count = json['datasets'].flat_map { |d| d['data'] }.sum
        expect(total_count).to eq(2)
      end
    end

    describe 'hour_of_day filter' do
      it 'filters page views by hour of day' do
        # Create Pages with specific slugs so their URLs match test expectations
        morning_page = create(:page, slug: 'morning-page')
        afternoon_page = create(:page, slug: 'afternoon-page')
        evening_page = create(:page, slug: 'evening-page')

        # Create page views with the associated Pages
        create(:metrics_page_view, pageable: morning_page, viewed_at: 10.days.ago.change(hour: 9))
        create(:metrics_page_view, pageable: afternoon_page, viewed_at: 10.days.ago.change(hour: 14))
        create(:metrics_page_view, pageable: evening_page, viewed_at: 10.days.ago.change(hour: 20))

        get "#{base_path}/page_views_by_url_data",
            params: { hour_of_day: 14 },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # URLs will be in format /en/afternoon-page
        expect(json['labels'].any? { |l| l.include?('afternoon-page') }).to be true
        expect(json['labels'].none? { |l| l.include?('morning-page') || l.include?('evening-page') }).to be true
        total_count = json['datasets'].flat_map { |d| d['data'] }.sum
        expect(total_count).to eq(1)
      end

      it 'returns all hours when no hour filter is specified' do
        # Create Pages with specific slugs
        morning_page = create(:page, slug: 'morning-page')
        afternoon_page = create(:page, slug: 'afternoon-page')
        evening_page = create(:page, slug: 'evening-page')

        # Create page views with the associated Pages
        create(:metrics_page_view, pageable: morning_page, viewed_at: 10.days.ago.change(hour: 9))
        create(:metrics_page_view, pageable: afternoon_page, viewed_at: 10.days.ago.change(hour: 14))
        create(:metrics_page_view, pageable: evening_page, viewed_at: 10.days.ago.change(hour: 20))

        get "#{base_path}/page_views_by_url_data",
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should count all three views
        expect(json['labels'].any? { |l| l.include?('morning-page') }).to be true
        expect(json['labels'].any? { |l| l.include?('afternoon-page') }).to be true
        expect(json['labels'].any? { |l| l.include?('evening-page') }).to be true
        total_count = json['datasets'].flat_map { |d| d['data'] }.sum
        expect(total_count).to eq(3)
      end
    end

    describe 'day_of_week filter' do
      it 'filters page views by day of week' do
        # Create Pages with specific slugs for day-of-week testing
        monday_page = create(:page, slug: 'monday-page')
        wednesday_page = create(:page, slug: 'wednesday-page')

        # Use recent dates within last 30 days
        # Jan 5, 2026 is Monday (DOW=1), Jan 7, 2026 is Wednesday (DOW=3)
        create(:metrics_page_view, pageable: monday_page, viewed_at: Time.zone.local(2026, 1, 5, 12, 0, 0))
        create(:metrics_page_view, pageable: wednesday_page, viewed_at: Time.zone.local(2026, 1, 7, 12, 0, 0))

        # Monday is day 1 in PostgreSQL's EXTRACT(DOW)
        get "#{base_path}/page_views_by_url_data",
            params: { day_of_week: 1 },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels'].any? { |l| l.include?('monday-page') }).to be true
        expect(json['labels'].none? { |l| l.include?('wednesday-page') }).to be true
        total_count = json['datasets'].flat_map { |d| d['data'] }.sum
        expect(total_count).to eq(1)
      end

      it 'returns all days when no day filter is specified' do
        # Create Pages with specific slugs for day-of-week testing
        monday_page = create(:page, slug: 'monday-page')
        wednesday_page = create(:page, slug: 'wednesday-page')

        # Use recent dates within last 30 days
        # Jan 5, 2026 is Monday (DOW=1), Jan 7, 2026 is Wednesday (DOW=3)
        create(:metrics_page_view, pageable: monday_page, viewed_at: Time.zone.local(2026, 1, 5, 12, 0, 0))
        create(:metrics_page_view, pageable: wednesday_page, viewed_at: Time.zone.local(2026, 1, 7, 12, 0, 0))

        get "#{base_path}/page_views_by_url_data",
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['labels'].any? { |l| l.include?('monday-page') }).to be true
        expect(json['labels'].any? { |l| l.include?('wednesday-page') }).to be true
        total_count = json['datasets'].flat_map { |d| d['data'] }.sum
        expect(total_count).to eq(2)
      end
    end

    describe 'combined filters' do
      it 'applies multiple filters together' do
        # Create Pages with specific slugs for combined filter testing
        spanish_afternoon = create(:page, slug: 'spanish-afternoon')
        english_afternoon = create(:page, slug: 'english-afternoon')
        spanish_morning = create(:page, slug: 'spanish-morning')

        # Create page views with the associated Pages
        create(:metrics_page_view,
               pageable: spanish_afternoon,
               locale: 'es',
               viewed_at: 10.days.ago.change(hour: 14))
        create(:metrics_page_view,
               pageable: english_afternoon,
               locale: 'en',
               viewed_at: 10.days.ago.change(hour: 14))
        create(:metrics_page_view,
               pageable: spanish_morning,
               locale: 'es',
               viewed_at: 10.days.ago.change(hour: 9))

        get "#{base_path}/page_views_by_url_data",
            params: { filter_locale: 'es', hour_of_day: 14 },
            headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Should only match the Spanish afternoon view
        expect(json['labels'].any? { |l| l.include?('spanish-afternoon') }).to be true
        expect(json['labels'].none? { |l| l.include?('english-afternoon') || l.include?('spanish-morning') }).to be true
        total_count = json['datasets'].flat_map { |d| d['data'] }.sum
        expect(total_count).to eq(1)
      end
    end
  end

  describe 'authorization' do
    context 'when user does not have view_metrics_dashboard permission', :no_auth do
      before do
        # Ensure host platform exists for route resolution
        configure_host_platform unless BetterTogether::Platform.exists?(host: true)
        # Explicitly sign out to override spec-level :as_platform_manager
        logout if respond_to?(:logout)
      end

      it 'returns 404 (route requires permission in constraint)' do
        # Unauthenticated users get routing error (404 in production) from route constraint
        expect do
          get "#{base_path}/page_views_by_url_data", headers: { 'Accept' => 'application/json' }
        end.to raise_error(ActionController::RoutingError, /No route matches/)
      end
    end
  end
end
