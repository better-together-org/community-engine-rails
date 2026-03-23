# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.10.0] – Unreleased

### Added

#### Settings — Developer Tab
- New **Developer** tab in `/settings` for authenticated users
- Personal OAuth application management: list, create, edit, delete owned OAuth apps
- Active access token table: view scopes, creation date, and revoke tokens
- Dedicated route `GET /settings/applications` for personal OAuth app CRUD

#### Community-Scoped Webhooks
- Community admins can manage webhook endpoints scoped to their community
- New `CommunityWebhookEndpointsController` with full CRUD and test delivery
- Routes nested under `/c/:community_id/webhook_endpoints`
- Community policy: `manage_integrations?` permission (delegates to `update?`)
- `WebhookEndpoint` model gains optional `community_id` FK

#### API Documentation
- `docs/api/oauth-integration-guide.md` — OAuth2 flows, scopes, token acquisition, GitHub login
- `docs/api/mcp-integration-guide.md` — MCP tool reference (20 tools), auth, client config
- `docs/api/webhook-integration-guide.md` — endpoint setup, event types, HMAC-SHA256 signing
- `docs/api/jwt-auth-guide.md` — Devise JWT auth, sign-in/sign-out, token claims

### Fixed
- `SettingsController#update_preferences` no longer crashes when re-rendering `:index` on validation failure — `load_developer_tab_data` extracted as shared private method
- Fixed `TypeError: Community is not a module` caused by module namespace collision — controller renamed to `CommunityWebhookEndpointsController` (flat-named)
- Fixed `before_action` ordering in `CommunityWebhookEndpointsController` — `set_community` now uses `prepend_before_action` to run before inherited `set_resource_instance`

### Tests
- 62 new request spec examples covering Developer tab, personal OAuth apps, and community webhooks
- All 173 related specs pass; full suite (5200+ examples) remains green

---

## [0.9.0] – 2026-02-25

### Added

#### OAuth2 / Doorkeeper
- Full Doorkeeper OAuth2 integration: authorization code flow (with PKCE), client credentials flow
- OAuth application management for platform managers (host dashboard)
- Doorkeeper authorization endpoint enabled (`/oauth/authorize`, `/oauth/token`)
- Token introspection restricted to the token's own application
- OAuth applications support `owner` association for user-scoped apps
- Hashed application secrets (Doorkeeper `:hash_application_secret`)
- Rack::Attack throttles for OAuth token endpoint

#### MCP Tools
- 20 MCP tools across 7 domains: communities, people, events, posts, conversations, marketplace, navigation/metrics
- Fast-MCP server via `/mcp/sse` (SSE) and `/mcp/messages` (HTTP) transports
- MCP authentication: `MCP_AUTH_TOKEN` shared token or `mcp_access` OAuth scope
- All tools enforce Pundit policies (privacy, blocking, membership scoping)

#### Webhooks
- `WebhookEndpoint` model: URL, name, description, HMAC secret (encrypted at rest), event filter array
- `WebhookDelivery` model: per-request audit record with status, response code/body, delivery timestamp
- `WebhookDeliveryJob`: HMAC-SHA256 signing (`TIMESTAMP.BODY`), headers `X-BT-Webhook-*`, retry with exponential backoff (3 attempts)
- `WebhookPublishable` concern: include in any model to publish `created`, `updated`, `destroyed` events
- `WebhookEndpoint.for_event` scope: empty events array = wildcard (receives all)
- Test delivery action on host dashboard webhook endpoint show page

#### API v1
- 20+ JSONAPI-compliant controllers covering communities, events, posts, people, conversations, uploads, geography, OAuth apps, webhooks, notifications, marketplace, metrics, agreements, navigation
- Dual authentication: Devise JWT (1-hour tokens) and Doorkeeper OAuth2 bearer tokens
- `OauthAuthorization` concern: per-action scope enforcement
- Pundit policies return 404 instead of 403 for security (no resource-existence leakage)
- JSONAPI paged paginator: `page[number]` / `page[size]` (default 20, max 100)

#### GitHub OAuth Social Login
- OmniAuth GitHub provider integration
- `OauthUser` model: provider/uid/token storage, linked to `User`
- `OmniauthCallbacksController` with `find_or_create_by` upsert logic
- Social login link on sign-in page

#### Security Hardening
- CSP nonce: `SecureRandom.base64(16)` per request (not session ID)
- CORS: default empty origins, explicit `Content-Type`/`Accept` header allowlist
- Doorkeeper: PKCE required, hashed secrets, restricted introspection
- Webhook secrets: `encrypts :secret` via Active Record Encryption
- `NavigationItem`: fixed operator precedence bug in `dropdown_with_visible_children?`
- Removed all `to_unsafe_h` calls in registration helpers
- Restricted email PII in `PersonResource` to authenticated context
- `WebhookEndpoint` mutations restricted to `:admin` OAuth scope
- Security audit TDD spec: 36 examples covering all critical paths
- Removed redundant `skip_before_action :verify_authenticity_token`

#### Calendar Feeds
- Calendar subscription token model
- Event recurrence model

#### Metrics
- Creator associations for content models
- User account reporting and metrics summary
- `GetMetricsSummaryTool` (MCP) with safe date parsing and auth guard

#### RBAC & Seeding
- Roles, permissions, and navigation items seeding task
- `better_together:seed:roles_and_permissions` installer task

#### Community Features
- Community invitations system
- Posts navigation items
- Checklist nested items support
- `manage_invitations?` community policy method

### Fixed
- Resolved 17 flaky spec failures caused by `ESSENTIAL_TABLES` accumulation and Mobility translation edge cases
- MCP auth hardening — additional headed Capybara option
- I18n: normalized `en.yml`, added missing OAuth/webhook translation keys, fixed misplaced keys
- API controllers: disabled remaining Rubocop metrics offenses for inherited JSONAPI controllers
- Spec schema: enforced Rails 7.2 compatibility via pre-commit hook

---

## [0.8.1] – (previous release)

See git history for changes prior to v0.9.0.

---

[0.10.0]: https://github.com/better-together-org/community-engine-rails/compare/v0.9.0...HEAD
[0.9.0]: https://github.com/better-together-org/community-engine-rails/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/better-together-org/community-engine-rails/releases/tag/v0.8.1
