# frozen_string_literal: true

require 'rails_helper'

# The billing tab of the metrics dashboard and its saved reports keep stable ids that styling, tests and screenshots rely on.
RSpec.describe 'Billing tax reports DOM', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'
  include_context 'with billing report data'

  let(:locale) { :en }
  let(:manager) { find_or_create_test_user("tax-report-dom-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }

  before { sign_in manager }

  it 'gives the dashboard a billing tab with charts', :aggregate_failures do
    get "/#{locale}/host/metrics/reports"
    page = Nokogiri::HTML(response.body)

    %w[billing-tab billing billing-charts-tab billing-reports-tab billing-summary chart-billing-revenue
       chart-billing-tax-by-rate].each do |id|
      expect(page.at_css("##{id}")).to be_present, "missing ##{id}"
    end
  end

  it 'gives the summary ids per currency', :aggregate_failures do
    order = paid_order(paid_at: 2.days.ago)
    line_for(order, cents: 10_000, taxes: [['HST', 0.15, 1500]])
    pay(order)
    get "/#{locale}/host/metrics/reports"
    page = Nokogiri::HTML(response.body)

    %w[billing-summary-cad billing-summary-cad-table billing-summary-cad-tax billing-summary-cad-tax-0
       billing-summary-cad-payments billing-summary-cad-payment-cash].each do |id|
      expect(page.at_css("##{id}")).to be_present, "missing ##{id}"
    end
  end

  it 'shows the empty note when nothing was sold' do
    get "/#{locale}/host/metrics/reports"

    expect(Nokogiri::HTML(response.body).at_css('#billing-summary-empty')).to be_present
  end

  it 'gives the saved reports list its ids', :aggregate_failures do
    report = BetterTogether::Metrics::BillingReport.create!(platform: host_platform, creator: manager.person, filters: { 'owner' => 'all' })
    get better_together.metrics_billing_reports_path(locale:)
    page = Nokogiri::HTML(response.body)

    expect(page.at_css('#billing-reports-table')).to be_present
    expect(page.at_css("#billing_report_#{report.id}")).to be_present
    expect(page.at_css('#billing-report-new-link')).to be_present
  end

  it 'gives the form its ids', :aggregate_failures do
    get better_together.new_metrics_billing_report_path(locale:)
    page = Nokogiri::HTML(response.body)

    %w[form from to interval owner format submit].each do |part|
      expect(page.at_css("#billing-report-#{part}")).to be_present, "missing #billing-report-#{part}"
    end
    %w[from to interval owner format].each do |part|
      expect(page.at_css("label[for='billing-report-#{part}']")).to be_present, "label not tied to #billing-report-#{part}"
    end
  end
end
