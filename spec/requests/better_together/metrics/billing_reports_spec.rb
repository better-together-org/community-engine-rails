# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::BillingReports' do # rubocop:disable RSpec/DescribeClass
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'
  include_context 'with billing report data'

  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let(:manager) { find_or_create_test_user("billing-report-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("billing-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:paid_at) { 3.days.ago }
  let(:params) do
    { metrics_billing_report: { file_format: 'csv', filters: { from_date: 10.days.ago.to_date.to_s, to_date: Date.current.to_s,
                                                               owner: 'platform', interval: 'month' } } }
  end

  def make_report(platform: host_platform)
    BetterTogether::Metrics::BillingReport.create!(platform:, creator: manager.person, filters: { 'owner' => 'all', 'interval' => 'month' })
  end

  # The metrics routes are behind a route constraint, so people without metrics access get no route at all.
  def reached?
    yield
    response.successful?
  rescue ActionController::RoutingError
    false
  end

  describe 'without permission' do
    it 'gives a visitor nothing' do
      expect(reached? { get metrics_billing_reports_path(locale:) }).to be(false)
    end

    it 'gives a member nothing, and makes no report', :aggregate_failures do
      sign_in member

      expect(reached? { get metrics_billing_reports_path(locale:) }).to be(false)
      expect do
        reached? { post metrics_billing_reports_path(locale:), params: }
      end.not_to change(BetterTogether::Metrics::BillingReport, :count)
    end

    it 'refuses an analytics viewer who does not manage the platform', :aggregate_failures do
      viewer = create(:better_together_user, :confirmed, email: "viewer-#{SecureRandom.hex(3)}@example.test", password:)
      BetterTogether::PersonPlatformMembership.create!(joinable: host_platform, member: viewer.person, status: 'active',
                                                       role: BetterTogether::Role.find_by!(identifier: 'platform_analytics_viewer'))
      sign_in viewer

      expect(reached? { get metrics_billing_reports_path(locale:) }).to be(false)
      expect(reached? { get "/#{locale}/host/metrics/reports/billing_revenue_data", as: :json }).to be(false)
    end
  end

  context 'when signed in as a platform manager' do
    before { sign_in manager }

    it 'lists reports, as a page and as a Turbo frame', :aggregate_failures do
      make_report
      get metrics_billing_reports_path(locale:)
      expect(response).to be_successful
      get metrics_billing_reports_path(locale:), headers: { 'Turbo-Frame' => 'billing_reports' }
      expect(response).to be_successful
      expect(response.body).to include('billing-reports-table')
    end

    it 'shows the form' do
      get new_metrics_billing_report_path(locale:)

      expect(response).to be_successful
    end

    it 'makes a report and queues its file', :aggregate_failures do
      expect do
        post metrics_billing_reports_path(locale:), params:
      end.to change(BetterTogether::Metrics::BillingReport, :count).by(1)
                                                                   .and have_enqueued_job(BetterTogether::Metrics::GenerateBillingReportJob)
      expect(response).to redirect_to(metrics_billing_reports_path(locale:))
    end

    it 'downloads the CSV', :aggregate_failures do
      line_for(paid_order(paid_at:), cents: 1000)
      report = BetterTogether::Metrics::BillingReport.create_and_generate!(creator: manager.person, platform: host_platform)
      perform_enqueued_jobs { BetterTogether::Metrics::GenerateBillingReportJob.perform_later(report.id) }

      get download_metrics_billing_report_path(report, locale:)

      expect(response).to be_successful
      expect(response.content_type).to start_with('text/csv')
      expect(response.body).to include('Currency')
    end

    it 'deletes a report' do
      report = make_report

      expect { delete metrics_billing_report_path(report, locale:) }.to change(BetterTogether::Metrics::BillingReport, :count).by(-1)
    end

    it 'cannot reach a report of another platform', :aggregate_failures do
      other = BetterTogether::Metrics::BillingReport.create!(platform: create(:better_together_platform), filters: { 'owner' => 'all' })

      get download_metrics_billing_report_path(other, locale:)
      expect(response).to have_http_status(:not_found)
      expect { delete metrics_billing_report_path(other, locale:) }.not_to change(BetterTogether::Metrics::BillingReport, :count)
    end
  end

  describe 'chart data' do
    let(:base) { "/#{locale}/host/metrics/reports" }
    let(:range) { { start_date: 10.days.ago.to_date.to_s, end_date: Date.current.to_s, currency: 'CAD', interval: 'month' } }

    before do
      order = paid_order(paid_at:)
      line_for(order, cents: 10_000, taxes: [['HST', 0.15, 1500]])
      pay(order)
    end

    it 'returns the revenue datasets', :aggregate_failures do
      sign_in manager
      get "#{base}/billing_revenue_data", params: range, as: :json

      body = response.parsed_body
      expect(response).to be_successful
      expect(body['datasets'].size).to eq(6)
      expect(body['datasets'].first['data'].sum).to eq(100.0)
    end

    it 'returns tax by rate' do
      sign_in manager
      get "#{base}/billing_tax_by_rate_data", params: range, as: :json

      expect(response.parsed_body['values']).to eq([15.0])
    end

    it 'refuses a member' do
      sign_in member

      expect(reached? { get "#{base}/billing_revenue_data", params: range, as: :json }).to be(false)
    end
  end
end
