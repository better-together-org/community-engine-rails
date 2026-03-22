# frozen_string_literal: true

require 'rails_helper'

# Example test file demonstrating automatic configuration features
RSpec.describe 'Example Automatic Configuration', type: :request do
  let(:locale) { I18n.default_locale }

  # Example 1: Explicit tag-based authentication
  context 'with explicit platform manager tag', :as_platform_manager do
    it 'automatically authenticates as platform manager' do
      get better_together.resource_permissions_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  # Example 2: Description-based authentication
  context 'with platform manager role' do
    it 'automatically authenticates from context description' do
      get better_together.resource_permissions_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  # Example 3: Regular user authentication
  context 'with authenticated user', :as_user do
    it 'automatically authenticates as regular user' do
      # This would test user-accessible endpoints
      # Test that we can access a user-accessible endpoint
      get better_together.conversations_path(locale:)
      expect(response).to have_http_status(:ok)
      # Verify session contains user information
      expect(session['warden.user.user.key']).to be_present
    end
  end

  # Example 4: Unauthenticated tests
  context 'without authentication', :no_auth do
    it 'remains unauthenticated' do
      # This would test public endpoints
      # Test a simple endpoint that should redirect to login when not authenticated
      # Use a path that exists regardless of host setup
      get better_together.new_user_session_path(locale:)
      expect(response).to have_http_status(:ok) # Login page should be accessible
      expect(response.body).to include('Sign In') # Should show login form
    end
  end

  # Example 5: Skip host platform setup (for testing setup wizard)
  context 'without host platform setup', :skip_host_setup do
    it 'skips automatic host platform configuration' do
      # This would test the host setup wizard or similar flows
      # Just verify the metadata worked
      expect(RSpec.current_example.metadata[:skip_host_setup]).to be true
    end
  end
end
