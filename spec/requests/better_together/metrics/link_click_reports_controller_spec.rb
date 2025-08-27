# frozen_string_literal: true

require 'rails_helper'

# rubocop:todo Metrics/BlockLength
RSpec.describe 'BetterTogether::Metrics::LinkClickReportsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  describe 'GET /:locale/.../metrics/link_click_reports' do
    it 'renders index' do
      get better_together.metrics_link_click_reports_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'renders new' do
      get better_together.new_metrics_link_click_report_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /:locale/.../metrics/link_click_reports' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'creates a report and redirects with valid params' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      post better_together.metrics_link_click_reports_path(locale:), params: {
        metrics_link_click_report: {
          file_format: 'csv',
          sort_by_total_clicks: false,
          filters: { from_date: '', to_date: '', filter_internal: '' }
        }
      }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end
# rubocop:enable Metrics/BlockLength
