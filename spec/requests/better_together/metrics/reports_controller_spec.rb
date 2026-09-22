# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::ReportsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/metrics/reports' do
    it 'renders the lightweight shell without running the search audit in the HTML request' do
      expect(BetterTogether::Search::AuditService).not_to receive(:new)

      get better_together.metrics_reports_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        'data-better-together--metrics-datetime-filter-initial-data-loaded-value="false"'
      )
      expect(response.body).to include(
        better_together.search_health_panel_metrics_reports_path(locale:)
      )
    end
  end
end
