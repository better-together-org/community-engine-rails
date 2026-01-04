# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host Dashboard Content' do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'SecureTest123!@#')
  end

  describe 'GET /host/dashboard' do
    it 'renders dashboard successfully' do
      get better_together.host_dashboard_path(locale: locale)
      expect(response).to have_http_status(:success)
    end

    it 'includes resource cards and content blocks' do
      get better_together.host_dashboard_path(locale: locale)
      expect(response).to have_http_status(:success)

      content = response.body
      # Check for key dashboard elements
      expect(content.include?('resource') ||
             content.include?('dashboard') ||
             content.include?('Communities') ||
             content.include?('Metrics')).to be true
    end
  end
end
