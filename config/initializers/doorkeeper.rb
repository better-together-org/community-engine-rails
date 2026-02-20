# frozen_string_literal: true

# Doorkeeper OAuth2 configuration for BetterTogether API
#
# This enables machine-to-machine (client_credentials) and
# user-delegated (authorization_code) OAuth2 flows for:
# - n8n workflow automation
# - MCP tool access
# - Third-party API integrations
# - Management tool instances

# Guard: only configure Doorkeeper when the gem is available
return unless defined?(Doorkeeper)

Doorkeeper.configure do # rubocop:disable Metrics/BlockLength
  # Use custom ORM models with BetterTogether namespace and UUID primary keys
  orm :active_record

  # Custom model classes (namespaced under BetterTogether)
  access_token_class 'BetterTogether::OauthAccessToken'
  access_grant_class 'BetterTogether::OauthAccessGrant'
  application_class 'BetterTogether::OauthApplication'

  # Resource owner authentication
  # For authorization_code flow: redirect unauthenticated users to sign in
  resource_owner_authenticator do
    current_user || warden.authenticate!(scope: :user)
  end

  # Admin authenticator for Doorkeeper dashboard
  # Only platform managers can manage OAuth applications
  admin_authenticator do
    if current_user&.person&.permitted_to?('manage_platform')
      current_user
    else
      redirect_to main_app.root_url, alert: I18n.t('doorkeeper.errors.unauthorized')
    end
  end

  # Authorization code expiry (10 minutes)
  authorization_code_expires_in 10.minutes

  # Access token expiry (2 hours — longer than JWT for fewer refresh cycles)
  access_token_expires_in 2.hours

  # Enable refresh token rotation
  use_refresh_token

  # Refresh tokens expire after 30 days
  custom_access_token_expires_in do |_context|
    2.hours
  end

  # Revoke old refresh tokens when a new one is issued
  revoke_previous_client_credentials_token

  # Enable PKCE for authorization code flow (prevents code interception attacks)
  force_pkce

  # Hash application secrets at rest
  hash_application_secrets

  # Available scopes for OAuth applications
  # Organized by resource type with read/write granularity
  default_scopes :read
  optional_scopes(
    :write,
    :admin,
    # Community resources
    :read_communities,
    :write_communities,
    # People resources
    :read_people,
    # Event resources
    :read_events,
    :write_events,
    # Content resources
    :read_posts,
    :write_posts,
    # Communication resources
    :read_conversations,
    :write_conversations,
    # Metrics & analytics
    :read_metrics,
    :write_metrics,
    # MCP-specific scope
    :mcp_access
  )

  # Grant flows enabled
  grant_flows %w[authorization_code client_credentials]

  # Restrict token introspection to the token's own application
  allow_token_introspection do |token, _authorized_token|
    token&.application.present?
  end

  # Skip authorization screen for trusted applications
  skip_authorization do |_resource_owner, client|
    client.application.trusted?
  end

  # Enforce configured scopes (reject tokens with unknown scopes)
  enforce_configured_scopes

  # Use custom error responses matching JSONAPI format
  handle_auth_errors :raise
end
