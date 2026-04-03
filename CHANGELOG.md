# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.11.0] – Unreleased

Detailed release packet: [docs/releases/0.11.0.md](docs/releases/0.11.0.md)

### Added

#### Multi-Tenant Platform Architecture & Federation MVP
- Full multi-tenant platform support: isolated `CurrentPlatform` context, per-tenant scoping across all models (#1215)
- Federation MVP: `PlatformConnection` model, OAuth-based cross-platform trust, `FederatedSeedAttributes` for content syndication
- `LinkedSeedIngestService`: receive and persist federated content (posts, pages, events) as local mirrors
- `PlatformConnectionsController` with full CRUD and federation OAuth token exchange flow
- Federation authorship opt-in: `federate_authorship` boolean on `Person` settings — authors who want attribution on federated platforms can opt in (#1408)
- `federated_author` JSONB column on posts, pages, and events for mirrored bylines
- Federation idempotent mirror lookup + identifier conflict namespacing (#1405)
- Federation member export consent controls for cross-platform sharing preferences (#1465)

#### End-to-End Encrypted Conversations
- Signal Protocol E2E encryption beta for conversations: `EncryptedConversation` model, key exchange, sealed-sender delivery (#1357)
- Disabled by default behind `BETTER_TOGETHER_E2EE_MESSAGING_ENABLED`; the E2EE bootstrap and send-form behaviors are mounted from conversation surfaces rather than the main application layout
- Activation guidance for `0.11.0`: limit enablement to opted-in deployments and intended conversation surfaces while V9/V10 bundle follow-ups remain open in the security model
- Encryption state stored per conversation; plaintext fallback remains available for legacy or not-yet-ready conversations

#### CMS Block System
- `BlockResource` base model and 19 concrete block type models: text, image, video, audio, map, embed, CTA, divider, accordion, checklist, mermaid diagram, and more (#1376)
- MCP tools for block management (create, update, delete, reorder)
- JSON:API endpoints for content blocks and page blocks (#1373)
- 12 additional content block types added in follow-up (#1350)
- Missing `blocks/new/_mermaid_diagram` partial restored (#1349)

#### Storage Adapter
- First-class `StorageConfiguration` model supporting local, S3, and S3-compatible (Garage, MinIO) backends (#1392)
- Admin UI for storage configuration management
- `aws-sdk-s3` integration with configurable endpoint override for S3-compatible stores

#### Seed Model & Personal Data Exports
- `BetterTogether::Seed` model for structured data snapshots (#790)
- Personal data export flow: `personal_export?` predicate, `PersonSeedsController` scoped to the authenticated user's own exports
- `PersonLinkedSeedPolicy` for policy-guarded seed access (#1403)

#### Privacy, Consent & Data Rights
- Member data export workflow with `PersonDataExport` / `PersonDeletionRequest` records for privacy-led self-service and review flows (#1468)
- Agreement acceptance audit trail with immutable method, identifier/title snapshot, revision timestamp, content digest, and privacy-safe audit context on `AgreementParticipant` (#1469)

#### Metrics & Reporting
- Platform-scoped analytics reads and writes across metrics dashboards, reports, summaries, and tracking jobs (#1461)
- Configurable metrics retention controls for raw analytics data (#1462)
- Reduced search query retention footprint to minimize stored personal data in analytics (#1463)

#### Content Authoring & SEO
- Image library selection flow for content block images (#999)
- JSON-LD structured data helpers for richer search engine metadata (#1024)
- Standard-page meta description helpers for improved previews and discovery (#1040)

#### MembershipRequest
- `MembershipRequest` STI model with `pending`/`approved`/`declined` states (#1356)
- Public JSONAPI endpoint: `POST /api/v1/membership_requests`
- Pundit policy enforcement; 404-not-403 leak prevention

#### Posts Index — Search, Filter & Pagination
- New `PostsSearchFilter` service: ILIKE text search (Mobility joins), category filter, privacy filter, order-by, Kaminari pagination (#1409)
- Sidebar `_list_form` partial (GET, bookmarkable filters)
- i18n keys under `better_together.posts.index.*`

#### Events Index — Unified Filterable View
- New `EventsSearchFilter` service: ILIKE text search, category filter, status filter, flexible order-by (soonest/latest/newest/oldest), Kaminari pagination (#1410)
- Replaces four hardcoded partition instance variables (`@draft_events` etc.) with a single filtered paginated `@events` relation
- Default view: upcoming events, soonest-first, 20 per page
- i18n keys under `better_together.events.index.*`

#### Safety Reporting Workflow
- Accessible safety reporting workflow with documentation (#1277)
- Report targets validated before auth to prevent enumeration

#### Rack::Attack
- Configurable Redis connection pool size and timeout for Rack::Attack rate limiting

#### Search
- Elasticsearch 8 gem upgrade validation (#1398)
- Audit, health reporting, and live ES validation tooling (#1393)
- Optional full reindex for all searchable models (#1276)

#### CI / Developer Experience
- Rails 8.1 informational CI lane (non-blocking) + versioned bundle helpers (#1391)
- Self-contained historical migrations: all legacy migrations carry their own `add_index`/`create_table` guards (#1402)
- Dual migration path support + FK ordering fixes (#1401)
- Share Docker services across worktrees for faster local dev (#1279)
- Repository write-boundary agent instructions

### Fixed
- **Authoring:** Preload event associations and add pagination to reduce host-side metrics and content list load issues (#1034)
- **Federation:** Narrow platform connection updates so host dashboards only mutate the intended fields (#1458)
- **Messaging:** Scope conversation participants to the current platform (#1459)
- **Navigation:** Seed navigation using the host platform context so installs pick up the correct platform-owned records (#1466)
- **Observability:** Log and report rescued production exceptions to both server logs and Sentry (#1472)
- **Uploads:** Restore same-origin profile image URLs through the Rails storage proxy instead of presigned direct S3 URLs (#1474)
- **Policies:** Restored `can_manage_platform_members?` to `PlatformInvitationPolicy` outer class after it was accidentally removed by the RBAC hardening commit — `index?`, `create?`, `destroy?`, `resend?` all call this method
- **Policies:** RBAC scope hardening — cleaner `PersonCommunityMembershipPolicy` / `PersonPlatformMembershipPolicy` resolution; tighter invitation role checks (#1403)
- **Middleware:** Cache host platform UUID (not the AR object) to prevent stale-object bugs (#1406)
- **Federation:** Pass `I18n.locale` to `federation_oauth_token_path` for correct locale-prefixed URLs
- **Engine:** Use exact match in `append_migrations` to include `spec/dummy` migrations correctly
- **Migrations:** Fix dual-path support, ordering, and FK bugs in migration loader (#1401)
- **Cache:** Update `RedisCacheStore` pool options for Rails 8 compatibility (#1353)
- **Routing:** Prevent `URI::InvalidURIError` on non-default locale + accented slug URLs (#1351)
- **Security:** Extend URI encoding; add Rack::Attack bot/scanner blocklists (#1352)
- **CI:** Restore main mailer and Rubocop green (#1384)
- **Performance:** Reduce N+1 queries on platform lookup and person profile pages (#1354)

### Security

- **CVE-2026-32700 (Devise):** Upgraded Devise to 5.0.3 across Rails 7.2, 8.0, and 8.1 compat branches (#1385, #1386, #1387). Existing password-reset tokens will be invalidated on upgrade — users with pending resets will need to re-request a new link.

---

## [0.10.0] – 2026-03-24

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

[0.11.0]: https://github.com/better-together-org/community-engine-rails/compare/v0.10.0...main
[0.10.0]: https://github.com/better-together-org/community-engine-rails/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/better-together-org/community-engine-rails/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/better-together-org/community-engine-rails/releases/tag/v0.8.1
