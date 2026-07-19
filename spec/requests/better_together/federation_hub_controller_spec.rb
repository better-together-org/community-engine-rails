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

  describe 'GET /activity' do
    it 'lists the signed-in person\'s own content activity' do
      post = create(:better_together_post, creator: regular_user.person)
      BetterTogether::Activity.create!(trackable: post, key: 'post.create', owner: regular_user.person)

      sign_in regular_user

      get better_together.federation_hub_activity_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.federation_hub.activity.keys.post_create',
                                              default: 'post.create'.humanize))
    end

    it 'does not show the direction filter to regular users' do
      sign_in regular_user

      get better_together.federation_hub_activity_path(locale:)

      expect(response.body).not_to include('name="direction"')
    end

    it 'shows the direction filter and connection activity to network admins' do
      connection = create(:better_together_platform_connection, :active)
      connection.mark_sync_succeeded!(item_count: 1)

      sign_in network_admin

      get better_together.federation_hub_activity_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.federation_hub.activity.keys.platform_connection_sync_succeeded'))
    end

    it 'is not reachable by a signed-out guest' do
      get better_together.federation_hub_activity_path(locale:)

      expect(response).to have_http_status(:not_found)
    end
  end
end
