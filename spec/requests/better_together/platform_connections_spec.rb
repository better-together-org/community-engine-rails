# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PlatformConnections', :no_auth do
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:network_admin) do
    create(:better_together_user, :confirmed, :network_admin, email: 'platform-network-admin@example.test')
  end
  let(:regular_user) { find_or_create_test_user('platform-connection-user@example.test', 'SecureTest123!@#', :user) }
  let(:platform_connection) { create(:better_together_platform_connection, :active) }

  describe 'GET /index' do
    it 'allows network admins to view platform connections' do
      sign_in network_admin

      get better_together.platform_connections_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Platform Connections')
      expect(response.body).to include(platform_connection.source_platform.name)
    end

    it 'hides platform connections from regular users' do
      sign_in regular_user

      get better_together.platform_connections_path(locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /update' do
    it 'allows network admins to update the connection' do
      sign_in network_admin

      patch better_together.platform_connection_path(platform_connection, locale:),
            params: { platform_connection: { status: 'suspended', content_sharing_enabled: true } }

      expect(response).to have_http_status(:see_other)
      expect(platform_connection.reload.status).to eq('suspended')
      expect(platform_connection.content_sharing_enabled).to be true
    end

    it 'rejects updates from regular users' do
      sign_in regular_user

      patch better_together.platform_connection_path(platform_connection, locale:),
            params: { platform_connection: { status: 'blocked' } }

      expect(response).to have_http_status(:not_found)
      expect(platform_connection.reload.status).to eq('active')
    end
  end
end
