# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::FederationHub', :no_auth do
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:network_admin) do
    create(:better_together_user, :confirmed, :network_admin, email: 'federation-hub-admin@example.test')
  end
  let(:regular_user) { find_or_create_test_user('federation-hub-user@example.test', 'SecureTest123!@#', :user) }

  describe 'GET /index' do
    it 'shows the personal content panel to any signed-in person, without admin sections' do
      sign_in regular_user

      get better_together.federation_hub_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.federation_hub.my_content_panel.title'))
      expect(response.body).not_to include(I18n.t('better_together.federation_hub.connection_health_card.title'))
    end

    it 'shows the connection health section to network admins' do
      sign_in network_admin

      get better_together.federation_hub_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.federation_hub.my_content_panel.title'))
      expect(response.body).to include(I18n.t('better_together.federation_hub.connection_health_card.title'))
    end

    it 'is not reachable by a signed-out guest' do
      get better_together.federation_hub_path(locale:)

      expect(response).to have_http_status(:not_found)
    end
  end
end
