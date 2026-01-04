# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics RBAC Authorization' do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
  end

  describe 'Platform Manager Access' do
    before do
      login('manager@example.test', 'SecureTest123!@#')
    end

    it 'allows access to metrics dashboard' do
      get better_together.metrics_reports_path(locale: locale)
      expect(response).to have_http_status(:success)
    end

    it 'allows access to page view reports' do
      get better_together.metrics_page_view_reports_path(locale: locale)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Unauthorized Access' do
    it 'denies access to unauthenticated users' do
      get better_together.metrics_reports_path(locale: locale)
      expect(response).to have_http_status(:not_found)
    end
  end
end
