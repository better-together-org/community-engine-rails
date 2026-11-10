# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_tax_reports_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_tax_reports_spec.rb.
RSpec.describe 'Documentation screenshots for the billing tax reports', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'
  include_context 'with billing report data'

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    [[40, 10_000, 1500, 'cash'], [20, 25_000, 3750, 'cheque'], [8, 4_000, 600, 'cash'],
     [3, 12_000, 1800, 'cash']].each do |days, cents, tax, how|
      order = paid_order(paid_at: days.days.ago)
      line_for(order, cents:, taxes: [['HST', 0.15, tax]])
      pay(order, processor: how)
    end
    paid = BetterTogether::Billing::Payment.order(:created_at).last
    refund_for(paid, amount: 2300, tax: 300, at: 1.day.ago)
    report = BetterTogether::Metrics::BillingReport.create_and_generate!(creator: nil, platform: host_platform, owner: 'platform',
                                                                         interval: 'month')
    BetterTogether::Metrics::GenerateBillingReportJob.perform_now(report.id)
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_tax_reports', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def open_billing_tab
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/host/metrics/reports"
    find('#billing-tab').click
  end

  it 'captures the billing summary and charts' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_tax_reports_charts', device: :both, metadata: metadata('billing_tax_reports_charts'),
                                    callouts: [{ id: 'charts', selector: '#chart-billing-revenue canvas', title: 'Revenue, tax and refunds',
                                                 avoid_container_selector: 'main',
                                                 bullets: ['Revenue by period: taxable, non-taxable, exempt.', 'Tax is net of refunds.'] }]
    ) do
      open_billing_tab
      expect(page).to have_css('#chart-billing-revenue')
      sleep 1.5
      scroll_to(find('#chart-billing-revenue canvas'), align: :center)
    end
  end

  it 'captures the summary tables' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_tax_reports_summary', device: :both, metadata: metadata('billing_tax_reports_summary'),
                                     callouts: [{ id: 'summary', selector: '#billing-summary-cad-table', title: 'The last 30 days',
                                                  avoid_container_selector: 'main',
                                                  bullets: ['Each currency is shown on its own.', 'Refunds are netted off.'] }]
    ) do
      open_billing_tab
      expect(page).to have_css('#billing-summary-cad-table')
      scroll_to(find('#billing-summary-cad-table'), align: :center)
    end
  end

  it 'captures the tax owed per administrator' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_tax_reports_authorities', device: :both, metadata: metadata('billing_tax_reports_authorities'),
                                         callouts: [{ id: 'authorities', selector: '#billing-summary-cad-authorities', title: 'Tax owed',
                                                      avoid_container_selector: 'main',
                                                      bullets: ['One line per tax administrator, net of refunds.'] }]
    ) do
      open_billing_tab
      expect(page).to have_css('#billing-summary-cad-authorities')
      scroll_to(find('#billing-summary-cad-authorities'), align: :center)
    end
  end

  it 'captures the saved reports list' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_tax_reports_saved', device: :both, metadata: metadata('billing_tax_reports_saved'),
                                   callouts: [{ id: 'saved', selector: '#billing-reports-table', title: 'Saved reports',
                                                avoid_container_selector: 'main', bullets: ['Download the CSV when it is ready.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/host/metrics/billing_reports"
      expect(page).to have_css('#billing-reports-table')
      scroll_to(find('#billing-reports-table'), align: :center)
    end
  end
end
