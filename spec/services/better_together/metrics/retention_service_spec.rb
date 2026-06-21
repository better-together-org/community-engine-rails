# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::RetentionService do
  include ActiveJob::TestHelper

  describe '#call' do
    let(:service) { described_class.new(raw_metrics_days: 180, report_days: 90, dry_run: dry_run) }
    let(:dry_run) { false }

    let!(:old_page_view_report) { create(:metrics_page_view_report, created_at: 91.days.ago, updated_at: 91.days.ago) }
    let!(:recent_page_view_report) { create(:metrics_page_view_report, created_at: 10.days.ago, updated_at: 10.days.ago) }
    let!(:old_link_click_report) { create(:metrics_link_click_report, created_at: 91.days.ago, updated_at: 91.days.ago) }
    let!(:recent_link_click_report) { create(:metrics_link_click_report, created_at: 10.days.ago, updated_at: 10.days.ago) }
    let!(:old_link_checker_report) { create(:metrics_link_checker_report, created_at: 91.days.ago, updated_at: 91.days.ago) }
    let!(:recent_link_checker_report) { create(:metrics_link_checker_report, created_at: 10.days.ago, updated_at: 10.days.ago) }
    let!(:old_user_account_report) { create(:user_account_report, :with_file, created_at: 91.days.ago, updated_at: 91.days.ago) }
    let!(:recent_user_account_report) { create(:user_account_report, :with_file, created_at: 10.days.ago, updated_at: 10.days.ago) }

    let!(:old_page_view) { create(:metrics_page_view, viewed_at: 181.days.ago) }
    let!(:recent_page_view) { create(:metrics_page_view, viewed_at: 10.days.ago) }
    let!(:old_link_click) { create(:metrics_link_click, clicked_at: 181.days.ago) }
    let!(:recent_link_click) { create(:metrics_link_click, clicked_at: 10.days.ago) }
    let!(:old_share) { create(:metrics_share, shared_at: 181.days.ago) }
    let!(:recent_share) { create(:metrics_share, shared_at: 10.days.ago) }
    let!(:old_download) { create(:metrics_download, downloaded_at: 181.days.ago) }
    let!(:recent_download) { create(:metrics_download, downloaded_at: 10.days.ago) }
    let!(:old_search_query) do
      BetterTogether::Metrics::SearchQuery.create!(
        query: 'old query',
        results_count: 1,
        locale: 'en',
        searched_at: 181.days.ago
      )
    end
    let!(:recent_search_query) do
      BetterTogether::Metrics::SearchQuery.create!(
        query: 'recent query',
        results_count: 2,
        locale: 'en',
        searched_at: 10.days.ago
      )
    end

    before do
      old_page_view_report.reload.report_file.attach(io: StringIO.new('old page view report'), filename: 'old-page-view.csv',
                                                     content_type: 'text/csv')
      recent_page_view_report.reload.report_file.attach(io: StringIO.new('recent page view report'),
                                                        filename: 'recent-page-view.csv', content_type: 'text/csv')
      old_link_click_report.reload.report_file.attach(io: StringIO.new('old link click report'),
                                                      filename: 'old-link-click.csv', content_type: 'text/csv')
      recent_link_click_report.reload.report_file.attach(io: StringIO.new('recent link click report'),
                                                         filename: 'recent-link-click.csv', content_type: 'text/csv')
      old_link_checker_report.reload.report_file.attach(io: StringIO.new('old link checker report'),
                                                        filename: 'old-link-checker.csv', content_type: 'text/csv')
      recent_link_checker_report.reload.report_file.attach(io: StringIO.new('recent link checker report'),
                                                           filename: 'recent-link-checker.csv', content_type: 'text/csv')
    end

    after do
      clear_enqueued_jobs
      clear_performed_jobs
    end

    it 'deletes only metrics and reports older than the configured cutoffs' do
      summary = perform_enqueued_jobs { service.call }

      expect(summary[:raw_metrics]).to include(
        'page_views' => include(eligible_count: 1, deleted_count: 1),
        'link_clicks' => include(eligible_count: 1, deleted_count: 1),
        'shares' => include(eligible_count: 1, deleted_count: 1),
        'downloads' => include(eligible_count: 1, deleted_count: 1),
        'search_queries' => include(eligible_count: 1, deleted_count: 1)
      )
      expect(summary[:reports]).to include(
        'page_view_reports' => include(eligible_count: 1, deleted_count: 1),
        'link_click_reports' => include(eligible_count: 1, deleted_count: 1),
        'link_checker_reports' => include(eligible_count: 1, deleted_count: 1),
        'user_account_reports' => include(eligible_count: 1, deleted_count: 1)
      )

      expect(BetterTogether::Metrics::PageView.exists?(old_page_view.id)).to be(false)
      expect(BetterTogether::Metrics::LinkClick.exists?(old_link_click.id)).to be(false)
      expect(BetterTogether::Metrics::Share.exists?(old_share.id)).to be(false)
      expect(BetterTogether::Metrics::Download.exists?(old_download.id)).to be(false)
      expect(BetterTogether::Metrics::SearchQuery.exists?(old_search_query.id)).to be(false)

      expect(BetterTogether::Metrics::PageView.exists?(recent_page_view.id)).to be(true)
      expect(BetterTogether::Metrics::LinkClick.exists?(recent_link_click.id)).to be(true)
      expect(BetterTogether::Metrics::Share.exists?(recent_share.id)).to be(true)
      expect(BetterTogether::Metrics::Download.exists?(recent_download.id)).to be(true)
      expect(BetterTogether::Metrics::SearchQuery.exists?(recent_search_query.id)).to be(true)

      expect(BetterTogether::Metrics::PageViewReport.exists?(old_page_view_report.id)).to be(false)
      expect(BetterTogether::Metrics::LinkClickReport.exists?(old_link_click_report.id)).to be(false)
      expect(BetterTogether::Metrics::LinkCheckerReport.exists?(old_link_checker_report.id)).to be(false)
      expect(BetterTogether::Metrics::UserAccountReport.exists?(old_user_account_report.id)).to be(false)

      expect(BetterTogether::Metrics::PageViewReport.exists?(recent_page_view_report.id)).to be(true)
      expect(BetterTogether::Metrics::LinkClickReport.exists?(recent_link_click_report.id)).to be(true)
      expect(BetterTogether::Metrics::LinkCheckerReport.exists?(recent_link_checker_report.id)).to be(true)
      expect(BetterTogether::Metrics::UserAccountReport.exists?(recent_user_account_report.id)).to be(true)
    end

    context 'when dry_run is enabled' do
      let(:dry_run) { true }

      it 'reports eligible rows without deleting them' do
        summary = service.call

        expect(summary[:raw_metrics]).to include(
          'page_views' => include(eligible_count: 1, deleted_count: 0),
          'search_queries' => include(eligible_count: 1, deleted_count: 0)
        )
        expect(summary[:reports]).to include(
          'page_view_reports' => include(eligible_count: 1, deleted_count: 0),
          'user_account_reports' => include(eligible_count: 1, deleted_count: 0)
        )

        expect(BetterTogether::Metrics::PageView.exists?(old_page_view.id)).to be(true)
        expect(BetterTogether::Metrics::UserAccountReport.exists?(old_user_account_report.id)).to be(true)
      end
    end
  end
end
