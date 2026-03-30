# frozen_string_literal: true

require 'rails_helper'
require 'cgi'

RSpec.describe 'BetterTogether::PlatformConnections', :no_auth do
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:network_admin) do
    create(:better_together_user, :confirmed, :network_admin, email: 'platform-network-admin@example.test')
  end
  let(:approval_operator) do
    create(:better_together_user, :confirmed, email: 'platform-approver@example.test')
  end
  let(:regular_user) { find_or_create_test_user('platform-connection-user@example.test', 'SecureTest123!@#', :user) }
  let!(:platform_connection) { create(:better_together_platform_connection, :active) }
  let(:source_platform) { create(:better_together_platform) }
  let(:target_platform) { create(:better_together_platform) }

  before do
    permission = BetterTogether::ResourcePermission.find_by(identifier: 'approve_network_connections')
    next unless permission

    role = create(:better_together_role, :platform_role)
    BetterTogether::RoleResourcePermission.create!(role:, resource_permission: permission)
    host_platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
    host_platform.person_platform_memberships.find_or_create_by!(member: approval_operator.person, role:)
  end

  describe 'GET /index' do
    it 'allows network admins to view platform connections' do
      sign_in network_admin

      get better_together.platform_connections_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Platform Connections')
      expect(response.body).to include(CGI.escapeHTML(platform_connection.source_platform.name))
    end

    it 'shows New Connection button to network admins' do
      sign_in network_admin

      get better_together.platform_connections_path(locale:)

      expect(response.body).to include('New Connection')
    end

    it 'hides platform connections from regular users' do
      sign_in regular_user

      get better_together.platform_connections_path(locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /new' do
    it 'renders the new connection form for network admins' do
      sign_in network_admin

      get better_together.new_platform_connection_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Platform Connection')
      expect(response.body).to include('Source Platform')
      expect(response.body).to include('Target Platform')
    end

    it 'denies new form to regular users' do
      sign_in regular_user

      get better_together.new_platform_connection_path(locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /create' do
    it 'creates a platform connection as network admin' do
      sign_in network_admin

      expect do
        post better_together.platform_connections_path(locale:),
             params: { platform_connection: {
               source_platform_id: source_platform.id,
               target_platform_id: target_platform.id,
               connection_kind: 'peer'
             } }
      end.to change(BetterTogether::PlatformConnection, :count).by(1)

      expect(response).to have_http_status(:see_other)
      connection = BetterTogether::PlatformConnection.last
      expect(connection.source_platform).to eq(source_platform)
      expect(connection.target_platform).to eq(target_platform)
      expect(connection.status).to eq('pending')
    end

    it 'renders new with errors when source and target are the same' do
      sign_in network_admin

      post better_together.platform_connections_path(locale:),
           params: { platform_connection: {
             source_platform_id: source_platform.id,
             target_platform_id: source_platform.id,
             connection_kind: 'peer'
           } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'denies connection creation to regular users' do
      sign_in regular_user

      expect do
        post better_together.platform_connections_path(locale:),
             params: { platform_connection: {
               source_platform_id: source_platform.id,
               target_platform_id: target_platform.id,
               connection_kind: 'peer'
             } }
      end.not_to change(BetterTogether::PlatformConnection, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /approve' do
    let(:pending_connection) { create(:better_together_platform_connection) }
    let(:suspended_connection) { create(:better_together_platform_connection, status: 'suspended') }

    it 'approves a pending connection as network admin' do
      sign_in network_admin

      patch better_together.approve_platform_connection_path(pending_connection, locale:)

      expect(response).to have_http_status(:see_other)
      expect(pending_connection.reload.status).to eq('active')
    end

    it 'approves a suspended connection as network admin' do
      sign_in network_admin

      patch better_together.approve_platform_connection_path(suspended_connection, locale:)

      expect(response).to have_http_status(:see_other)
      expect(suspended_connection.reload.status).to eq('active')
    end

    it 'redirects with alert when approving an already active connection' do
      sign_in network_admin

      patch better_together.approve_platform_connection_path(platform_connection, locale:)

      expect(response).to have_http_status(:see_other)
      expect(platform_connection.reload.status).to eq('active')
    end

    it 'denies approval to regular users' do
      sign_in regular_user

      patch better_together.approve_platform_connection_path(pending_connection, locale:)

      expect(response).to have_http_status(:not_found)
      expect(pending_connection.reload.status).to eq('pending')
    end

    it 'allows approval-only operators to approve a pending connection' do
      sign_in approval_operator

      patch better_together.approve_platform_connection_path(pending_connection, locale:)

      expect(response).to have_http_status(:see_other)
      expect(pending_connection.reload.status).to eq('active')
    end
  end

  describe 'PATCH /suspend' do
    it 'suspends an active connection as network admin' do
      sign_in network_admin

      patch better_together.suspend_platform_connection_path(platform_connection, locale:)

      expect(response).to have_http_status(:see_other)
      expect(platform_connection.reload.status).to eq('suspended')
    end

    it 'redirects with alert when suspending a non-active connection' do
      pending_connection = create(:better_together_platform_connection)
      sign_in network_admin

      patch better_together.suspend_platform_connection_path(pending_connection, locale:)

      expect(response).to have_http_status(:see_other)
      expect(pending_connection.reload.status).to eq('pending')
    end

    it 'denies suspension to regular users' do
      sign_in regular_user

      patch better_together.suspend_platform_connection_path(platform_connection, locale:)

      expect(response).to have_http_status(:not_found)
      expect(platform_connection.reload.status).to eq('active')
    end
  end

  describe 'PATCH /update' do
    it 'allows network admins to update the connection' do
      sign_in network_admin

      patch better_together.platform_connection_path(platform_connection, locale:),
            params: { platform_connection: {
              status: 'suspended',
              content_sharing_policy: 'mirror_network_feed',
              federation_auth_policy: 'api_read',
              share_posts: true,
              allow_identity_scope: true,
              allow_content_read_scope: true
            } }

      expect(response).to have_http_status(:see_other)
      expect(platform_connection.reload.status).to eq('active')
      expect(platform_connection.content_sharing_enabled).to be true
      expect(platform_connection.content_sharing_policy).to eq('mirror_network_feed')
      expect(platform_connection.share_posts).to be true
      expect(platform_connection.federation_auth_policy).to eq('api_read')
    end

    it 'rejects updates from regular users' do
      sign_in regular_user

      patch better_together.platform_connection_path(platform_connection, locale:),
            params: { platform_connection: { status: 'blocked' } }

      expect(response).to have_http_status(:not_found)
      expect(platform_connection.reload.status).to eq('active')
    end

    it 'rejects generic updates from approval-only operators' do
      sign_in approval_operator

      patch better_together.platform_connection_path(platform_connection, locale:),
            params: { platform_connection: { federation_auth_policy: 'api_write' } }

      expect(response).to have_http_status(:not_found)
      expect(platform_connection.reload.federation_auth_policy).not_to eq('api_write')
    end
  end
end
