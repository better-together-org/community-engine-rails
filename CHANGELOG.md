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
- 12 additional content block types implemented in follow-up, with page-builder rollout deferred until a 0.11.x patch review (#1350)
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
- GDPR-oriented deletion audit inventory, anonymization, manifest, and hard-deletion executor flows, plus account-tab deletion-request cleanup (#1486)

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

#### Access Modes & Review Flow
- Community access-mode surfaces now distinguish open-join and request-to-join states consistently across public community pages, registration interstitials, and organizer review flows (#1500)
- Membership request review queue/detail evidence and related docs/diagrams now reflect the shipped organizer moderation path instead of leaving that flow implicit (#1500)

#### Inbound Mail Relay
- Action Mailbox-powered inbound email relay MVP with Better Together router mailboxes, tenant-safe resolution/routing, and persisted inbound message records (#1501)

#### Content Security & Reporting
- Content-security ingress workflow for uploads and rich-text attachments with under-review/restricted states and a review queue for release decisions (#1504)
- Refreshed reporting surfaces and guidance: non-page report menus remain in place, page views gain a bottom feedback bar, and safety-routing copy is clearer for reporters and reviewers (#1504)

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
- `pg_search`-backed default search backend with database fallback for models that have not yet been upgraded to dedicated `pg_search` scopes
- Audit and backend-visibility tooling for the registry-backed search lane (#1393)
- Optional full reindex for all searchable models (#1276)
- `SearchPagesTool` plus a shared AREL content-search helper for page-oriented MCP search paths (#1273)

#### CI / Developer Experience
- Rails 8.1 informational CI lane (non-blocking) + versioned bundle helpers (#1391)
- Self-contained historical migrations: all legacy migrations carry their own `add_index`/`create_table` guards (#1402)
- Dual migration path support + FK ordering fixes (#1401)
- Share Docker services across worktrees for faster local dev (#1279)
- Repository write-boundary agent instructions
- Rails branch maintenance workflows plus native Rails lint-lane fixes (#1281)
- Tiered PR evidence requirements with validator-backed screenshot/diagram/doc enforcement (#1497)

#### AI / Adapter Infrastructure
- Provider adapter architecture scaffold for pluggable AI and service backends (#1491)
- Robot configuration system documentation and resolution-flow artefacts for persisted AI-capable robot records (#1493)

#### C3 Tree Seeds — Community Contribution Token System
- `BetterTogether::C3::Token` model for recording community contribution credits with platform scoping and cross-platform federation support
- `BetterTogether::C3::TokenSeed` STI type for federated token-seed distribution via the federation API (`/api/v1/c3/token_seeds`)
- `BetterTogether::Joatu::Settlement` model + `Agreement#fulfill!` lifecycle method to complete the C3 spending chain
- Balance locking with decimal-precision arithmetic via `C3::BalanceLock`; `ExpireBalanceLocksJob` handles automatic expiry of stale locks
- Borgberry fleet integration: migrations, models, and API endpoints for fleet-node contribution tracking and autonomous earning
- Operator-owned settlement notifications via `C3::SettlementMailer` and `C3::SettlementNotifier`
- `PlatformConnection` C3 scope + token-origin tracking as federation prerequisites for cross-platform token exchange
- i18n coverage: C3 and settlement locale keys for English, Spanish, French, and Ukrainian
- Architecture documentation: `docs/c3/` (what-is-c3, data-model, flows, network-and-security, regulatory considerations), `docs/borgberry-ce-integration.md`, `docs/c3-federation-design.md`

#### Short Links & Share Domain
- `BetterTogether::ShortLink` model with configurable slug, polymorphic target, optional expiry, and click tracking (#1594)
- `Shortlinkable` concern: attach a managed share URL to any model with one line
- Share button UI component with clipboard copy-to-clipboard (Stimulus `clipboard` controller), integrated on post, page, and event surfaces
- Platform-scoped short-link index and management views (`GET /c/:community/short_links`)
- Public redirect endpoint at `GET /r/:slug`
- Stable `dom_id`/`dom_class` DOM identifiers on all new short-link views per the View DOM Identifier Standard

#### Fleet Node Authorization
- `FleetNodePolicy` + Pundit authorization on `NodesController` to prevent unauthorized fleet-node management via the fleet API

### Fixed
- **Content Blocks:** Production readiness fixes for markdown, video, and iframe blocks; restored `content_addable? = true` on 11 regressed block types; all blocks enabled and PR #1492 review findings resolved
- **Uploads:** Honor upload content-security state toggles; align upload download authorization to the content-security review state
- **Federation:** Namespace mirrored content imports to prevent cross-tenant identifier collisions (#1597); add idempotent repair migration for federated mirrored identifier backfill; localize federation remediation messages (es/fr/uk)
- **C3:** Rename `BalanceLocking#lock!` → `lock_c3!` to stop shadowing `ActiveRecord` pessimistic locking; qualify error constant namespacing; validate `lock_ref` upfront before lock acquisition
- **Provider Gems:** Load provider extension gems as optional non-bundled extensions to keep the core engine bundle clean (#1596)
- **Assets:** Restore Leaflet vendor assets for importmap compatibility
- **RC Hardening:** Address 0.11.0 RC merge blockers — scope fixes, route cleanup, and compatibility patches (#1598)
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
- **Migrations:** Avoid platform permission position collisions during the `0.11.0` release-upgrade path
- **Cache:** Update `RedisCacheStore` pool options for Rails 8 compatibility (#1353)
- **Navigation:** Correct header/footer visibility cache keys and helper memoization for access-context-sensitive navigation rendering (#1274)
- **Routing:** Prevent `URI::InvalidURIError` on non-default locale + accented slug URLs (#1351)
- **Security:** Extend URI encoding; add Rack::Attack bot/scanner blocklists (#1352)
- **CI:** Restore main mailer and Rubocop green (#1384)
- **Performance:** Reduce N+1 queries on platform lookup and person profile pages (#1354)
- **Settings / Privacy:** Move account deletion requests into the account tab and retire the legacy My Data seed section after the deletion-audit rollout
- **Auth / UX:** Hide OAuth sign-in buttons when provider credentials are not configured
- **API:** Remove the stray `created_at` attribute from `InvitationResource`

### Security

- **CVE-2026-32700 (Devise):** Upgraded Devise to 5.0.3 across Rails 7.2, 8.0, and 8.1 compat branches (#1385, #1386, #1387). Existing password-reset tokens will be invalidated on upgrade — users with pending resets will need to re-request a new link.
- **SSRF (Federation):** Added `ssrf_filter` gem to close SSRF DNS rebinding attack vector in federation outbound HTTP requests; all federated outbound requests are now filtered against private and loopback address ranges.

### Dependencies (post-#1547 updates)

- Devise 5.0.4 (patch after 5.0.3 security release)
- ruby_llm 1.15.0
- sidekiq 8.1.5
- nokogiri 1.19.3
- active_storage_validations 3.0.5
- faraday 2.14.2, bootsnap 1.24.4
- rubocop-rails 2.35.2, selenium-webdriver 4.44.0, parallel_rspec 3.1.0
- icalendar 2.12.3, css_parser 1.22.0, doorkeeper 5.9.1, jwt 3.2.0
- aws-sdk-s3 1.223.0

### Known Limitations & Deferred Surfaces

The following subsystems shipped their backend model, API, and migration foundations in
0.11.0 but do **not** yet include organizer or end-user CE UI. They are accessible via
the JSON:API or Borgberry agent runtime only. Organizer UI is planned for 0.11.x patches.

- **Fleet Nodes (`BetterTogether::Fleet::Node`):** API-only in 0.11.0. No CE admin or
  organizer views exist for inspecting or managing fleet nodes registered with a platform.
  Fleet node management operates exclusively through the Borgberry agent runtime.
- **C3 Token Ledger — Organizer View:** `C3::Token`, `C3::Balance`, and `C3::ExchangeRate`
  have full API support but no organizer-facing CE UI for inspecting or managing community
  token balances. Organizers receive C3 activity indirectly through JOATU settlement
  notifications.
- **Inbound Mail — Admin Inspection:** The Action Mailbox MVP provides routing and
  persisted inbound message records but no organizer UI for inspecting routing failures or
  reviewing delivered messages. This is intentionally a documentation-first runtime
  surface for 0.11.0.
- **MermaidDiagram Block — PNG Fallback:** The Mermaid Diagram content block renders
  correctly in JavaScript-enabled environments. A PNG fallback for non-JavaScript users is
  not yet implemented; those users will see no diagram content. Targeted for a 0.11.x
  patch.
- **Share Button — Open Graph Image:** The share button component ships without an
  Open Graph image field populated. Share previews on external platforms will not include
  a thumbnail image. Targeted for a 0.11.x patch.
- **`DocumentationBuilder` Navigation Item:** The documentation navigation builder is
  disabled in 0.11.0 pending documentation-tree readiness. The infrastructure is in
  place; activation will follow documentation content completion.
- **`AgreementParticipant` Legacy Shim:** A backwards-compatibility shim for
  `person_id`-based queries remains in `AgreementParticipant` through the 0.11.x series.
  It will be removed in 0.12.0 once all callers are migrated to the new participant
  resolution path.
- **ClamAV Operator Deploy Guide:** A guide for deploying, configuring, and monitoring
  the ClamAV backend will be added in a 0.11.x docs patch before operators are expected
  to enable `BETTER_TOGETHER_CONTENT_SECURITY_CLAM_AV_ENABLED`.

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
