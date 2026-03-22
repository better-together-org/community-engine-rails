# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host Dashboard Content', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /host/dashboard' do
    it 'renders the host dashboard successfully' do
      get better_together.host_dashboard_path(locale: locale)

      expect(response).to have_http_status(:success)

      # Test that the response contains dashboard-related content
      dashboard_content = response.body.downcase
      expect(
        dashboard_content.include?('dashboard') ||
        dashboard_content.include?('host') ||
        dashboard_content.include?('resource')
      ).to be true
    end

    it 'includes resource cards like Communities, Conversations, People' do
      get better_together.host_dashboard_path(locale: locale)

      expect(response).to have_http_status(:success)

      # Test for some of the key resource cards
      content = response.body.downcase
      expect(
        content.include?('communities') ||
        content.include?('conversations') ||
        content.include?('people')
      ).to be true
    end
  end
end
