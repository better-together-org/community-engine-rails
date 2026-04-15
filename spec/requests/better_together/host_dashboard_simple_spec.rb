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

    it 'surfaces a membership review queue with direct review links' do
      community = create(:better_together_community, name: 'Reviewable Community')
      create(:better_together_joatu_membership_request, target: community, requestor_name: 'Alex Applicant')

      get better_together.host_dashboard_path(locale: locale)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Membership review queue')
      expect(response.body).to include('Reviewable Community')
      expect(response.body).to include(better_together.community_membership_requests_path(community, locale: locale))
    end
  end
end
