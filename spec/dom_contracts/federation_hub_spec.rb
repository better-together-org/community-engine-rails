# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the Federation Hub: asserts the stable identifiers that
# documentation screenshots (spec/docs_screenshots/better_together/
# federation_hub_spec.rb) and downstream tooling target. Runs in normal CI
# (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Federation Hub DOM contract', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:network_admin) do
    create(:better_together_user, :confirmed, :network_admin, email: 'dom-contract-network-admin@example.test')
  end
  let(:regular_user) { find_or_create_test_user('dom-contract-federation-hub-user@example.test', 'SecureTest123!@#', :user) }

  describe 'GET /federation-hub' do
    it 'exposes the personal panel identifiers to any signed-in person' do
      sign_in regular_user

      get better_together.federation_hub_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="federation-hub-index"')
      expect(response.body).to include('id="federation-hub-visibility-counts"')
      expect(response.body).to include('id="federation-hub-count-platform-default"')
      expect(response.body).to include('id="federation-hub-count-federate"')
      expect(response.body).to include('id="federation-hub-count-no-federate"')
    end

    it 'exposes the admin connection-health identifiers to network admins' do
      sign_in network_admin

      get better_together.federation_hub_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="federation-hub-connection-badges"')
      expect(response.body).to include('id="federation-hub-total-badge"')
      expect(response.body).to include('id="federation-hub-pending-badge"')
      expect(response.body).to include('id="federation-hub-active-badge"')
      expect(response.body).to include('id="federation-hub-review-connections-link"')
    end
  end

  describe 'GET /federation-hub/activity' do
    it 'exposes the activity feed identifiers' do
      sign_in network_admin

      get better_together.federation_hub_activity_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="federation-hub-activity"')
      expect(response.body).to include('id="federation-hub-activity-filters"')
    end
  end
end
