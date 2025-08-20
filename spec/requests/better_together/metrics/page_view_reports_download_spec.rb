# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::PageViewReportsController download' do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'downloads an attached report file' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    report = BetterTogether::Metrics::PageViewReport.create!(file_format: 'csv')
    report.report_file.attach(
      io: StringIO.new('col1,col2\n1,2\n'),
      filename: 'report.csv',
      content_type: 'text/csv'
    )

    get better_together.download_metrics_page_view_report_path(locale:, id: report.id)
    expect(response).to have_http_status(:ok)
    expect(response.header['Content-Type']).to include('text/csv')
  end
end
