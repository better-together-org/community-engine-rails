# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host Dashboard Content' do
  let(:locale) { I18n.default_locale }

  # Use manual authentication for now to avoid conflicts
  before do
    configure_host_platform

    # Login as platform manager
    manager_user = BetterTogether::User.find_by(email: 'manager@example.test') ||
                   create(:better_together_user, :confirmed,
                          email: 'manager@example.test',
                          password: 'SecureTest123!@#')

    platform = BetterTogether::Platform.find_by(host: true)
    platform_manager_role = BetterTogether::Role.find_by!(identifier: 'platform_manager')

    unless platform.person_platform_memberships.exists?(member: manager_user.person, role: platform_manager_role)
      platform.person_platform_memberships.create!(
        member: manager_user.person,
        role: platform_manager_role
      )
    end

    # Login for request specs
    post better_together.user_session_path(locale: locale), params: {
      'better_together_user' => {
        'email' => 'manager@example.test',
        'password' => 'SecureTest123!@#'
      }
    }

    follow_redirect! if response.redirect?
  end

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
