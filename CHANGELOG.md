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
- Per-item federation consent: tri-state `federation_visibility` on Post/Page/Event, per-connection sync intervals, and rate-limited federation feed delivery
- RBAC platform-scoping remediation across 27 policy files, closing several unscoped `manage_platform`/`manage_platform_settings` checks — see Security
- `new_platform_setup` wizard: a distinct, platform-scoped flow for provisioning additional tenant platforms (separate from the singleton host-bootstrap wizard), with a full accessibility pass
- Platform Domains admin UI (`PlatformDomainsController`) — previously required Rails console/rake task access (#1677)
- Federation Hub: a new top-level nav destination showing any signed-in person their own content's federation status and connection health, plus a paginated activity feed
- First-class `BetterTogether::StorageConfiguration` adapter (local/S3/S3-compatible), AR-encrypted credentials, admin CRUD (#1392)
- Community Action Network governance system: `GovernedAgent` identity scaffold and agreement-gated public publishing (#1494)
- Per-platform multi-tenant sitemaps and dynamic, tenant-aware `robots.txt`

#### Removed
- Signal Protocol E2E encrypted-messaging beta (prekey exchange, Double Ratchet, sender-key group rotation, passphrase key backup) pulled from the 0.11.0 release pending further security hardening (open V9/V10 findings). Preserved intact on `feature/e2e-signal-protocol-messaging-01100notes` for future rework.
- C3 Tree Seeds community contribution token system, including the Borgberry fleet-compute integration and fleet-node authorization, relocated to a standalone extension gem rather than shipping in core 0.11.0.
- Claim/Citation/Evidence governance foundation pulled from the 0.11.0 release. Reintegration tracked as draft PR #1797, not part of this release.

#### CMS Block System
- `BlockResource` base model and 19 concrete block type models: text, image, video, audio, map, embed, CTA, divider, accordion, checklist, mermaid diagram, and more (#1376)
- 8 MCP tools for block/page-block management: `SearchPagesTool`, `PublishPostTool`, `UpdatePostTool`, `ListPageBlocksTool`, `GetBlockTool`, `CreatePageBlockTool`, `UpdateBlockTool`, `DeletePageBlockTool`
- JSON:API endpoints for content blocks and page blocks (#1373)
- All 13 new content block types (Accordion, Alert, Call to Action, Checklist, Communities, Events, Iframe, Navigation Area, People, Posts, Quote, Statistics, Video) ship standard as of 2026-09-18 — the earlier `new_content_blocks` alpha gate has been removed entirely (#1350)
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

#### Messaging
- `MessageRequest` model/policy/controller: lets a member send a messaging-permission request with an explanatory note to someone who hasn't granted them direct-messaging access; accepting opens a conversation and records an explicit `PersonMessagingGrant`
- Gated behind the `message_requests` feature (alpha rollout — see `config/feature_gates.yml`), enforced server-side in `MessageRequestPolicy` (not just hidden in the UI)

#### Access Modes & Review Flow
- Community access-mode surfaces now distinguish open-join and request-to-join states consistently across public community pages, registration interstitials, and organizer review flows (#1500)
- Membership request review queue/detail evidence and related docs/diagrams now reflect the shipped organizer moderation path instead of leaving that flow implicit (#1500)

#### Inbound Mail Relay
- Action Mailbox-powered inbound email relay MVP with Better Together router mailboxes, tenant-safe resolution/routing, and persisted inbound message records (#1501)
- Reply-by-email: `reply+<token>@` resolves a single-use, per-recipient reply token back to the originating conversation/comment (#1690)
- SPF/DKIM/DMARC verification of inbound senders via trusted `Authentication-Results:`/`Received-SPF:` headers (#1691)
- Authorization hardening across all alias kinds: membership-request submission by email now honors the same gate as the web form, a platform-level `allow_inbound_mail` kill switch was added, and `agent+` sender identity is now verified against the resolved person's actual email instead of trusted from a guessable identifier alone (#1689)

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
- Branch-native Rails compatibility lanes (7.2 / 8.0 / 8.1) via `compat-branch-sync.yml`, `dependency-compatibility.yml`, and `dependabot-auto-merge.yml` — supersedes the earlier informational-only Rails 8.1 preview lane (#1391, #1281)
- Self-contained historical migrations: all legacy migrations carry their own `add_index`/`create_table` guards (#1402)
- Dual migration path support + FK ordering fixes (#1401)
- Share Docker services across worktrees for faster local dev (#1279)
- Repository write-boundary agent instructions
- Rails branch maintenance workflows plus native Rails lint-lane fixes (#1281)
- Tiered PR evidence requirements with validator-backed screenshot/diagram/doc enforcement (#1497)

#### AI / Adapter Infrastructure
- Provider adapter architecture scaffold for pluggable AI and service backends (#1491)
- Robot configuration system documentation and resolution-flow artefacts for persisted AI-capable robot records (#1493)

#### Short Links & Share Domain
- `BetterTogether::ShortLink` model with configurable slug, polymorphic target, optional expiry, and click tracking (#1594)
- `Shortlinkable` concern: attach a managed share URL to any model with one line
- Share button UI component with clipboard copy-to-clipboard (Stimulus `clipboard` controller), integrated on post, page, and event surfaces
- Platform-scoped short-link index and management views (`resources :short_links`, under the authenticated-user namespace)
- Public redirect endpoint at `GET /s/:code` (open redirect by design — scheme-validated `target_url`, platform-scoped lookup, no target-host allowlist)
- Stable `dom_id`/`dom_class` DOM identifiers on all new short-link views per the View DOM Identifier Standard

#### Geography
- PostGIS-backed geography hierarchy resolution: any geocoded Address/Building/Event point resolves to its containing Continent/Country/State/Region/Settlement via polygon containment, with ISO country-code and name-similarity fallbacks (#1667)
- Boundary-polygon import from Nominatim/Geocoder, plus operator rake tasks for backfill, seed-catalog generation, and reference-data import
- Redesigned, accessible location picker (mixed-type search, inline-create rows) replacing the prior radio-group type selector (#1781)
- `Geography::Map#platform_id` added and `Geography::Map`/JOATU matching scoped to platform boundaries — see Security (#1766)
- `privacy` column added to the geography and category reference-data tables

### Fixed
- **Content Blocks / Hero images:** two bugs kept a hero/background image from displaying for anonymous visitors. (1) `block_styles` emitted `background-image: url(<proxy-url>)` **unquoted**; ActiveStorage appends the blob filename as the last path segment, so any file with `(`, `)`, a space or a comma in its name (e.g. `photo(1).jpg`) produced a CSS syntax error and the whole declaration was dropped -- now quoted (`url("...")`). (2) `Content::Block#privacy` defaults to `'private'` and nothing syncs it from the page, so blocks predating the 0.11.0 `authorize_blob_access` gate (#1392) had their images return 401 even on a public homepage -- new backfill migration `20260902190000` makes visible blocks on published public pages `public` (raw SQL, mirroring `20251219191929` for navigation items).
- **Migrations / Platform scoping:** `20260321000003_backfill_content_platform_id` and the phase backfills resolve their target platform as "the row `WHERE host = TRUE`" at migration time. During the federation bootstrap the host flag briefly sits on a seed `community-engine` platform that is then demoted to `external = TRUE`, so content stamped in that window ends up scoped to a platform that `PlatformRecordPolicy::Scope` now hides from every request — on host apps this silently replaced the homepage with the generic Community Engine page and 404'd the other static pages (observed on `newfoundlandlabrador.online`: 11 pages incl. the homepage). New idempotent repair migration `20260902180000_repair_local_content_scoped_to_external_platforms` moves locally-authored content (`source_id IS NULL`) — pages, posts, events, navigation, content blocks, and mis-scoped `community_id` — off `external = TRUE` platforms back to the host platform, collision-guarded on `(identifier, platform_id)` and a no-op on a correctly-scoped instance.
- **Federation:** `HttpAdapter` resolved every outbound feed/token URL from `connection.source_platform` unconditionally, so a connection where the local platform happened to be `source_platform` (rather than `target_platform`) pulled federated content from itself instead of the actual peer — silently breaking one direction of every federation link. Resolve the peer via each platform's `external?` flag instead. Also add exponential backoff (5min–6hr) on consecutive `PlatformConnection` sync failures so an unreachable partner is not re-dispatched every hourly scan tick, harden the TCP reachability pre-check to rescue `IO::TimeoutError`, and normalize `SsrfFilter::TooManyRedirects`/`UnresolvedHostname` to the existing `SSRFError` alongside `PrivateIPAddress`.
- **Content Blocks:** Production readiness fixes for markdown, video, and iframe blocks; restored `content_addable? = true` on 11 regressed block types; all blocks enabled and PR #1492 review findings resolved
- **Uploads:** Honor upload content-security state toggles; align upload download authorization to the content-security review state
- **Federation:** Namespace mirrored content imports to prevent cross-tenant identifier collisions (#1597); add idempotent repair migration for federated mirrored identifier backfill; localize federation remediation messages (es/fr/uk)
- **Provider Gems:** Load provider extension gems as optional non-bundled extensions to keep the core engine bundle clean (#1596)
- **Assets:** Restore Leaflet vendor assets for importmap compatibility
- **RC Hardening:** Address 0.11.0 RC merge blockers — scope fixes, route cleanup, and compatibility patches (#1598)
- **Error Reporting:** `BetterTogether::ApplicationJob` now routes background-job exceptions through the same `BetterTogether.report_error` adapter dispatch used by `ApplicationController#handle_error` — previously only request-level errors reached a host app's registered error reporter (e.g. the `:bts_local` structured-JSON reporter), so job failures across the ~27 jobs built on `ApplicationJob` had no coverage. Implemented as an `around_perform` rather than `rescue_from` so it doesn't shadow a subclass's own `retry_on`/`discard_on` handlers.
- **Authoring:** Preload event associations and add pagination to reduce host-side metrics and content list load issues (#1034)
- **Federation:** Narrow platform connection updates so host dashboards only mutate the intended fields (#1458)
- **Messaging:** Scope conversation participants to the current platform (#1459)
- **Navigation:** Seed navigation using the host platform context so installs pick up the correct platform-owned records (#1466)
- **Observability:** Log and report rescued production exceptions through `BetterTogether.report_error`'s pluggable adapter-registry dispatch, now also covering background-job errors via `ApplicationJob` (#1472). Note: `sentry-rails`/`sentry-ruby` were removed as core dependencies this cycle — a host app or extension gem must register its own Sentry (or other) adapter for exception reports to reach an external service; without one, core CE only guarantees `Rails.error.report`.
- **Comments:** Deleting a comment no longer cascades to destroy its linked moderation `Report`/`Safety::Case` record; a moderator-block gap on comment destroy closed; comment length capped; the content-publishing agreement is now actually enforced on new comments; credited co-authors are now notified on new comments; the long-dormant `notify_on_comments` preference is now wired end-to-end.
- **Reliability:** Upgraded Ruby 3.4.4 → 3.4.10, fixing a reproducible `socket.rb` heap-use-after-free segfault (upstream Ruby Bug #21443) that was crashing Puma in production roughly 1-2x/day; paired with a new `mcp/sse/ip` Rack::Attack throttle closing the underlying trigger (an MCP SSE-reconnect loop holding Puma threads open).
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
- **Security:** `ApplicationController#set_locale` assigned `params[:locale]`/`session[:locale]` straight to `I18n.locale=` with no validation — a malformed or malicious locale (blind-SQLi scanner probes were observed in production) raised `I18n::InvalidLocale` as an unhandled 500; now falls back to the default locale. `UrlSanitizer::URI_UNSAFE_ASCII` (added for #1351/#1352) still excluded `"` and `,` — a scanner probe using those characters reached `URI.parse` unescaped and raised the same error class; extended the character class to close the gap.
- **CI:** Restore main mailer and Rubocop green (#1384)
- **Performance:** Reduce N+1 queries on platform lookup and person profile pages (#1354)
- **Settings / Privacy:** Move account deletion requests into the account tab and retire the legacy My Data seed section after the deletion-audit rollout
- **Auth / UX:** Hide OAuth sign-in buttons when provider credentials are not configured
- **API:** Remove the stray `created_at` attribute from `InvitationResource`

### Security

- **CVE-2026-32700 (Devise):** Upgraded Devise to 5.0.3 across Rails 7.2, 8.0, and 8.1 compat branches (#1385, #1386, #1387). Existing password-reset tokens will be invalidated on upgrade — users with pending resets will need to re-request a new link.
- **SSRF (Federation):** Added `ssrf_filter` gem to close SSRF DNS rebinding attack vector in federation outbound HTTP requests; all federated outbound requests are now filtered against private and loopback address ranges.
- **Cross-tenant admin takeover (RBAC):** `UserPolicy` and 26 other policy files checked `manage_platform`/`manage_platform_settings` permissions with no platform argument, so any tenant's admin could view and edit every other tenant's records — most severely, every other tenant's `User` accounts (email, password, and admin flags included) via `UserPolicy`. Fixed by threading the target record's own platform into every check (#1762).
- **Privilege escalation via host-platform membership backfill:** A data migration (`BackfillHostPlatformMemberships`) granted every backfilled person the platform's highest-privilege role instead of the low-privilege role a companion migration had specifically seeded for this purpose. This had confirmed real-world impact on two live hosts before the fix landed (#1687).
- **Cross-tenant ActiveStorage service hijack:** A tenant admin could activate their own storage configuration as the shared/global storage service, rerouting every other tenant's file storage through credentials they controlled (#1763).
- **ActiveStorage direct uploads had zero authentication:** Rails core's `DirectUploadsController` bypasses the host application's controller stack entirely; every CE-family app had unauthenticated direct-upload endpoints until this cycle closed the gap (#1750, #1392).
- **Unsafe reflection in `BlocksController`:** `params[:resource_class].safe_constantize` ran on unvalidated input (Brakeman High-confidence, RCE-class); fixed with a strict class allowlist.
- **Inbound mail person-impersonation:** `agent+<identifier>@` resolved a real `Person` from a guessable identifier with no verification the sender owned that identity, allowing a message to be routed/attributed as if from an arbitrary real person; fixed alongside the other alias-authorization gaps (#1689).

### Dependencies

- **ruby_llm** 2.0.0.rc4 (exact-pinned) — fixes CVE-2026-67991 (ReDoS, no patched 1.x release exists); replaces `ruby-openai`, which is removed
- **Devise** 5.0.4 — fixes CVE-2026-32700 and CVE-2026-40295 (open redirect via `Referer` header)
- **css_parser** promoted to an explicit `>= 3.0.0` gemspec dependency — fixes CVE-2026-53727 (SSRF + LFI); pulls in the new `ssrf_filter` dependency
- **nokogiri** 1.19.4 — multiple use-after-free / out-of-bounds-read / null-pointer GHSA fixes
- **Rails family** (actionpack, activestorage, etc.) 8.0.5.1 — fixes CVE-2026-66066 (ActiveStorage/libvips arbitrary file read / RCE)
- **puma** 8.0.2 (major bump from the 7.x line) — fixes CVE-2026-47736 / CVE-2026-47737 (PROXY protocol memory exhaustion)
- **oauth2** 2.0.23 (transitive) — fixes GHSA-pp92-crg2-gfv9 (bearer-token leak via protocol-relative redirect)
- Removed: `elasticsearch-model`/`elasticsearch-rails` (replaced by `pg_search`, a Postgres-native search backend — Elasticsearch itself now lives in a standalone `better_together-elasticsearch` extension gem, no longer a core dependency), `sentry-rails`/`sentry-ruby` (see Observability, above)
- sidekiq 8.1.6, active_storage_validations 3.0.5, faraday 2.14.3, bootsnap 1.24.6, rubocop-rails 2.35.5, selenium-webdriver 4.44.0
- icalendar 2.12.3 (CVE-2026-33635), doorkeeper 5.9.3, jwt 3.2.0 (CVE-2026-45363), aws-sdk-s3 1.227.0

A full dependency audit (every security-motivated, major/breaking, minor/patch, added, and removed gem) is available in the 0.11.0 release assessment; this section covers the highlights.

### Known Limitations & Deferred Surfaces

The following subsystems shipped their backend model, API, and migration foundations in
0.11.0 but do **not** yet include organizer or end-user CE UI. Organizer UI is planned
for 0.11.x patches.

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
- **Observability & Marketing Adapters:** Core error reporting now dispatches through a
  pluggable adapter registry, but no companion observability gem (e.g. Sentry) has
  shipped yet — that extraction is roadmap-only. There is no dedicated marketing/Google
  Analytics gem either; a small inline GA tracking hook was replaced by a generic
  `share` browser event that a host app or future extension gem can listen for.
- **SPF/DKIM/DMARC Verification:** `InboundMailAuthentication` (#1691) is implemented
  and merged but is currently inert in production pending a separate do-3 infrastructure
  change to set a stable `AuthservID`; deploy the two together.

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
