# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::PageViewReportsController download', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let!(:host_platform) { configure_host_platform }
  # rubocop:todo RSpec/MultipleExpectations
  it 'downloads an attached report file' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations

    report = BetterTogether::Metrics::PageViewReport.create!(file_format: 'csv', platform: host_platform)
    report.report_file.attach(
      io: StringIO.new('col1,col2\n1,2\n'),
      filename: 'report.csv',
      content_type: 'text/csv'
    )

    get better_together.download_metrics_page_view_report_path(locale:, id: report.id)
    expect(response).to have_http_status(:ok)
    expect(response.header['Content-Type']).to include('text/csv')
  end

  it 'does not download a report from another platform' do
    report = BetterTogether::Metrics::PageViewReport.create!(file_format: 'csv', platform: create(:better_together_platform))

    get better_together.download_metrics_page_view_report_path(locale:, id: report.id)

    expect(response).to have_http_status(:not_found)
  end
end
