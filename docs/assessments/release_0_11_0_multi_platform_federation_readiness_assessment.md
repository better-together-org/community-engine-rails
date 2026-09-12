# 0.11.0 Multi-Platform, Multi-Tenancy & Federation Release-Readiness Assessment

**Date:** July 17, 2026
**Assessment Type:** Release-readiness architecture and process assessment
**Repository:** better-together-org/community-engine-rails
**Branch assessed:** `release/0.11.0-notes` (commit `bb4158f23`)
**Scope:** The 0.11.0 "multi-platform multi-tenancy and federation" theme — platform/domain data model, tenant data scoping, in-app and operational processes for creating new platforms with unique domains (subdomains of the host domain and fully custom domains), external OAuth, and federation between Community Engine platforms.

---

## Executive Summary

0.11.0 is the largest architectural shift in Community Engine's history. The backend is **substantially real and well-tested**: ~80 models were backfilled with `platform_id` and now inherit consistent tenant scoping, a new `PlatformDomain` hostname-resolution layer with request-scoped middleware exists, a `PlatformConnection` federation trust model with its own OAuth2 client-credentials transport layer is implemented and tested, and external OAuth login (GitHub) is production-quality. Twelve-plus mermaid architecture diagrams and a real, already-run screenshot pipeline back the release packet.

Three things this assessment was specifically asked to verify have real, documented gaps:

1. **No general-purpose in-app UI to create a platform with a chosen domain.** The only paths are a Rails console / idempotent rake task (ops-only, always available) and — pending PR [#1581](https://github.com/better-together-org/community-engine-rails/pull/1581) (open, not yet merged) — a billing-gated self-serve form for paying customers. Neither offers a subdomain-vs-custom-domain picker; both just take a raw `host_url`.
2. **No end-to-end (system/browser) test of the platform-creation-with-domain flow existed before this assessment.** Request/model/service specs cover domain resolution and isolation well, but nothing exercised the *combined* "provision → attach domain → verify isolation" flow until this assessment did so directly (see the validated runbook, `docs/production/multi_platform_deployment.md`).
3. **Federation is explicitly self-documented as not production-safe yet.** CE's own `docs/developers/systems/federation_system.md` states: *"production activation should remain conservative until the planned consent architecture is complete"* — a person-level federation consent gate is planned (`docs/plans/federation-consent-identity.md`) but not yet built.

None of this blocks documenting and shipping what exists; it does mean the "create a platform with a unique domain" story is currently an **operator/ops runbook**, not a self-service product feature (except behind a paywall, once PR #1581 merges), and federation should stay off by default in production until the consent gate lands.

---

## 1. Platform / Domain / Tenant Data Model

- **`Platform`** (`app/models/better_together/platform.rb`) — translated `name` (slugged), `host_url` (aliased to/from `url`, required + unique, SSRF-validated), `time_zone` (validated against `TZInfo`), `external` (marks OAuth-identity-provider platforms), `host` (boolean; exactly one row may be `true`, enforced by the `PlatformHost` concern's `single_host_record` validation), `privacy`, and a `settings` JSON store (`requires_invitation`, `allow_membership_requests`, `network_visibility`, `federation_protocol`, `feature_gate_rollouts`, …). Composed from ~14 concerns including `PlatformHost`, `PlatformRegistryDefaults`, `PlatformCspConfiguration`, `Joinable`, `Privacy`, `PrimaryCommunity`.
- **Platform ↔ Community:** `PrimaryCommunity` concern (`app/models/concerns/better_together/primary_community.rb:24-42`) auto-creates a 1:1 `belongs_to :community` `before_validation` if absent — every `Platform` owns exactly one primary `Community`, inheriting its `host:`/`protected:` flags.
- **`PlatformDomain`** (`app/models/better_together/platform_domain.rb`) — maps a `hostname` to a `Platform`, with `primary_flag` (canonical domain, single-record-per-platform via the `PrimaryFlag` concern) and `share_domain` (used for share URLs, also single-record-per-platform, defaults to the first domain created). `Platform#sync_primary_platform_domain!` (`platform_registry_defaults.rb:29-39`) auto-creates/updates the primary domain from `host_url` on every create/update, via an `after_commit` hook.
- **`PlatformInvitation`**, **`PersonPlatformMembership`** (role-based via the `Joinable` pattern — `platform_steward`/`platform_manager` roles), **`PlatformConnection`** (federation trust edges, see §5), and **`TenantPlatformProvisioningService`** (see §3) round out the core model.

**There is no code-level distinction between "subdomain of the host domain" and "fully custom domain."** Both are just a `hostname` string on a `PlatformDomain` row — see the runbook (§3 below and `docs/production/multi_platform_deployment.md`) for the operational distinction, which is entirely about DNS delegation and TLS certificate strategy, not application logic.

---

## 2. Domain Resolution At Runtime

`app/middleware/better_together/platform_context_middleware.rb` is Rack middleware, run ahead of the entire stack (web, JSON:API, MCP). It reads `request.host`, calls `PlatformDomain.resolve(hostname)` — a 5-minute cached lookup (`platform_domain.rb:29-34`) — and sets `Current.platform`/`Current.platform_domain`, falling back to the cached host-platform ID if no domain matches.

**Confirmed: there is no route-level subdomain constraint anywhere in `config/routes.rb`.** All platforms are dispatched by one single Rails application, distinguished purely by the `Host` header — not by Rails routing constraints, not by separate app instances, not by separate database schemas. This was independently re-verified end-to-end (see §3 "Validated Runbook").

---

## 3. Creating A New Platform Today (Processes & Their Gaps)

Two provisioning surfaces exist:

### 3a. Ops path — `TenantPlatformProvisioningService` + rake task (always available, admin-only)

`app/services/better_together/tenant_platform_provisioning_service.rb`, exposed via `lib/tasks/better_together/provision_tenant.rake` (`rails better_together:provision_tenant[name,host_url,time_zone,admin_email,admin_password,admin_name]`). It is:
- **Idempotent** — `find_or_initialize_by(host_url:)`, safe to re-run.
- **Transactional** — a partial failure rolls back the platform, community, domain, and admin user together.
- Optionally provisions an admin/steward `User` with `platform_steward` + `community_governance_council` roles.

This is console/rake-only — **no admin UI wraps it.** `PlatformsController#new/#create` (`app/controllers/better_together/platforms_controller.rb:65-97`) exists, but `platform_create_params` only permits `identifier, host_url, time_zone, external` — it is not a usable "create a platform with a domain" UI, and doesn't expose `host:` or any domain-alias management.

### 3b. Self-serve path — billing-gated provisioning (PR #1581, **not yet merged**)

Open PR [`#1581`](https://github.com/better-together-org/community-engine-rails/pull/1581) (`codex/ce-billing-foundation-release-0.11.0-notes` → `release/0.11.0-notes`, Stripe-first billing foundation) adds `CommunityBillingsController#provision_platform`/`#create_platform_provision` (routes `GET`/`POST community_billing_path(...)/provision_platform`), gated behind `HostedEntitlementResolver#active?` — a community needs an active paid hosted plan to provision a platform through this path. It calls the same underlying service, but:
- **Renames** the service's `admin:` keyword to `steward:`, adds a `privacy:` keyword (default `'private'`, vs. the current hard-coded `'public'`), and changes the default `time_zone` from `'UTC'` to `'America/St_Johns'`. This is a **breaking signature change** to `TenantPlatformProvisioningService`.
- The new form (`app/views/better_together/community_billings/provision_platform.html.erb`) exposes only `name`, `host_url`, `time_zone`, `privacy` — **still no subdomain-vs-custom-domain picker**, just a raw `host_url` text field.
- **Steward isn't set during self-serve provisioning** — the view's own copy says "Platform stewardship access can be configured after provisioning."
- Test coverage for the new controller actions is real (`spec/requests/better_together/community_billings_spec.rb`) — covers entitlement gating (active/past_due/no-subscription) and success/failure redirects — but **mocks `TenantPlatformProvisioningService` entirely**, so it does not itself assert `PlatformDomain` creation. That assertion lives in the service's own spec (`spec/services/better_together/tenant_platform_provisioning_service_spec.rb`), which was updated in the same PR ("auto-creates a PlatformDomain via model callback") and still passes.

**As of this assessment (2026-07-17), PR #1581 is OPEN — the current tip of `release/0.11.0-notes` still uses the `admin:` signature, `'UTC'` default time zone, and hard-coded `'public'` privacy.** Any documentation or tooling referencing the provisioning service must be re-checked against this PR's merge status (see the implementation plan, item P1-4).

### 3c. Validated runbook

The full provision → attach-subdomain → attach-custom-domain → resolve → isolation-check flow was **actually executed** against this branch in a disposable test database (not just read from source) as part of this assessment. All six steps passed. Full commands, code, and output are recorded in `docs/production/multi_platform_deployment.md` under "Validated Provisioning Walkthrough (tested 2026-07-17)" — that section is the actionable, tested process this assessment was asked to produce.

---

## 4. Tenant Data Isolation

- **`PlatformScoped`** concern (`app/models/concerns/better_together/platform_scoped.rb`) adds `belongs_to :platform`, `scope :for_platform`, and auto-assigns `Current.platform` on create if blank.
- **`PlatformRecord`** (`app/models/better_together/platform_record.rb`) is an abstract base including `PlatformScoped`; **~80 models** inherit from it (Page, Post, Event, Comment, Community, Role, ResourcePermission, Conversation, Report, WebhookEndpoint, User, Person, etc.).
- Isolation is **application-level only** — no Postgres Row-Level Security exists in this codebase (confirmed: no RLS/`pg_policy`/`ENABLE ROW LEVEL SECURITY` anywhere). Everything relies on developers using `.for_platform(...)` — this was independently re-verified to actually isolate data correctly in the validated runbook (§3c), but it remains a convention, not a database-enforced guarantee.
- **Large backfill campaign in 0.11.0:** dozens of migrations ("Phase 5" through "Phase 13") added `platform_id` to previously-unscoped tables and enforced NOT NULL + unique-index rescoping. This is the core of the 0.11.0 tenancy-hardening work.
- **Inconsistently-scoped models — flagged for explicit review, not fixed in this pass:**
  - `C3::Balance`, `C3::Token`, `C3::BalanceLock` — plain `ApplicationRecord`, not `PlatformScoped`/`PlatformRecord`, despite having `platform_id`/`origin_platform_id` columns. Plausibly intentional (C3 is meant to be a cross-platform ledger), but undocumented as a deliberate exception.
  - `PersonLinkedSeed` — uses `belongs_to :source_platform` directly rather than the standard concern.
  - **New in this assessment (found via PR #1581 review):** `Billing::Plan`, `Billing::Subscription`, `Billing::Event` (all added by PR #1581) are also plain `ApplicationRecord`. They're owned polymorphically (`belongs_to :owner`, Community or Person), not platform-scoped — again plausibly intentional (a billing plan catalog might be host-platform-level and offered network-wide), but it's the same "intentional or not, please document the decision" pattern as the two items above.
- The most commonly-cited internal gap document, `docs/assessments/multi_tenancy_gap_assessment_2026-03-11.md`, **predates PR #1215** (merged ~March 21–26, 2026), which built most of the `PlatformDomain`/`PlatformRecord`/backfill infrastructure described here. It has been annotated with a superseded-by banner pointing to this document (see that file).

---

## 5. External OAuth

- Devise + OmniAuth. `config/initializers/devise.rb:294` registers **only GitHub**: `config.omniauth :github, ENV['GITHUB_CLIENT_ID'], ENV['GITHUB_CLIENT_SECRET'], scope: 'user:email'`. `config/initializers/omniauth_env_validation.rb` lists `facebook`, `google_oauth2`, `linkedin` as commented-out/future providers.
- `PersonPlatformIntegration::PROVIDERS` (`app/models/better_together/person_platform_integration.rb:9-14`) enumerates `facebook`, `github`, `google_oauth2`, `linkedin` as supported values — **but Google/Facebook/LinkedIn are not actually wired up**; only `def github` is active in `app/controllers/better_together/omniauth_callbacks_controller.rb` / `.../users/omniauth_callbacks_controller.rb` (Facebook is a commented-out stub).
- Identity linkage: `DeviseUser#from_omniauth` (`app/models/concerns/better_together/devise_user.rb`) and `PersonPlatformIntegration.update_or_initialize` create a `PersonPlatformIntegration` per OAuth connection. Interestingly, `PersonPlatformIntegration.find_external_platform_for_provider` auto-creates a non-host `Platform` record representing the *external OAuth provider itself* (e.g. a `Platform` named "Github", `host: false`, `external: true`) — provider-as-platform bookkeeping, not multi-tenant login.
- **No cross-platform SSO exists.** Each CE Rails deployment is its own tenant boundary with one `host: true` Platform; OAuth sign-in resolves/creates a `User`/`Person` scoped to that single running instance's database. A GitHub identity established on Platform A cannot authenticate a session on Platform B without the federation `PersonLink` claim flow (§6), which is explicitly planned architecture, not completed runtime.
- Test coverage is solid: `spec/requests/better_together/users/omniauth_callbacks_spec.rb`, `spec/controllers/better_together/users/omniauth_callbacks_controller_spec.rb` (620 lines), `spec/controllers/better_together/users/omniauth_authentication_flows_controller_spec.rb` (389 lines), `spec/models/concerns/better_together/devise_user_spec.rb`, `spec/models/better_together/person_platform_integration_github_spec.rb`.

**Bottom line:** external OAuth login is fully implemented and production-quality, but GitHub-only, and it is a single-tenant-instance login mechanism, not a multi-platform identity federation mechanism.

---

## 6. Federation Between Community Engine Platforms

This is the headline 0.11.0 feature, and it is extensive but **explicitly self-flagged as not production-safe yet**:

- **Trust model:** `BetterTogether::PlatformConnection` (`app/models/better_together/platform_connection.rb`) — a directed edge between `source_platform` and `target_platform`, with `status` (pending/active/suspended/blocked), `connection_kind` (peer/member), content-sharing/auth policies, and per-scope allow flags (identity, profile_read, content_read, linked_content_read, content_write) plus C3-token-exchange settings.
- **M2M auth:** `app/controllers/better_together/federation/oauth_tokens_controller.rb` — an OAuth2 client_credentials grant scoped to a `PlatformConnection` (routes under `federation/`: `POST federation/oauth/token`, `GET federation/content_feed`, `GET federation/linked_seeds`, `POST federation/c3/token_seeds`, `POST federation/c3/lock_requests`). Tokens are `BetterTogether::FederationAccessToken` (SHA256-digested, scope-checked, connection-bound). This is **separate from Doorkeeper**, which serves the general JSON:API OAuth2 surface for n8n/MCP/management-tool clients.
- **Content mirroring:** `FederatedContentPullJob`/`FederatedContentPullService`/`FederatedContentIngestService`/`FederatedContentAuthorizer` pull posts/pages/events from peer platforms as local mirrors, tracked via sync-state fields on `PlatformConnection` (cursor, last_sync_status). A new transport layer (`app/services/better_together/federation/transport/{direct_adapter,http_adapter,transport_resolver}.rb`) added in 0.11.0 provides a `DirectAdapter` (same-instance/multi-tenant testing) and an `HttpAdapter` (real cross-instance HTTP, hardened with the `ssrf_filter` gem).
- **Not ActivityPub** — no `.well-known`, no ActivityPub vocabulary. This is a bespoke OAuth2 client_credentials + JSON pull-sync protocol.
- **Person identity across federation:** `PersonLink`/`PersonLinkedSeed` models exist for eventual identity-claim/merge across platforms, and `Person#federate_content` (a boolean, default `false`) is the intended consent gate — **but the full person-stub + claim-flow architecture is still in progress**, targeted for v0.11.1. `docs/developers/systems/federation_system.md:118-141` states outright: *"The current implementation is stronger at operator-configured platform trust than at person-level federation consent... there is not yet a completed person-level consent gate that prevents a member's content from being exported unless they explicitly opt in. Because of that gap, production activation should remain conservative until the planned consent architecture is complete."* The forward plan is tracked separately at `docs/plans/federation-consent-identity.md` — this assessment does not duplicate that plan (see the implementation plan, §P0).
- **UI is real, not just API:** `PlatformConnectionsController` gives organizers full CRUD/approve UI, and `HostDashboardController` has a federation-review queue at route `federation-review`.
- **C3 token federation** (`docs/c3-federation-design.md`) is a larger aspirational cross-platform token-portability design; per the CHANGELOG's own "Known Limitations," C3 currently has "full API support but no organizer-facing CE UI."
- **Test coverage** is broad: `spec/requests/better_together/federation/{oauth_tokens,content_feed,linked_seeds,c3_lock_requests,c3_token_seeds}_spec.rb`, `spec/requests/better_together/platform_connections_spec.rb` (26 examples), `spec/services/better_together/federation_scope_authorizer_spec.rb`, `federation_connection_provisioning_service_spec.rb`, `spec/models/better_together/{platform_connection,federation_access_token}_spec.rb`, transport adapter specs.

**Bottom line:** platform-to-platform federation has a substantial, real, well-tested backend — but per CE's own documentation, it should not be activated in production until the consent-gate work lands. This assessment treats that as the single hard release blocker for federation specifically (not for multi-tenancy/domain provisioning generally, which has no equivalent blocker).

---

## 7. Docs, Diagrams & Screenshots Inventory

- **`CHANGELOG.md`** has a `[0.11.0] – Unreleased` section headed "Multi-Tenant Platform Architecture & Federation MVP," listing `Current.platform` scoping, `PlatformConnection`, OAuth cross-platform trust, `FederatedSeedAttributes`, `LinkedSeedIngestService`, `federate_authorship` opt-in, idempotent mirror/identifier-namespacing, and member export consent.
- **`docs/releases/0.11.0.md`** is the canonical release packet — its Section 1, "Federation, multi-tenancy, and platform scoping," is described there as "the largest architectural shift in 0.11.0," with an explicit screenshot-coverage checklist (setup wizard, platform-connections index/editor, host-platform profile, storage adapter UI, federation/membership/safety review tabs).
- **Diagrams:** `docs/diagrams/` has 12+ mermaid sources with matching PNG/SVG exports directly relevant here — `ce_platform_network_rails_layers.mmd`, `ce_platform_network_schema_erd.mmd`, `federation_content_mirroring_flow.mmd`, `federation_oauth_trust_flow.mmd`, `federation_platform_connection_flow.mmd`, `multi_tenant_platform_runtime_flow.mmd`, `platform_manager_admin_flow.mmd`, `platform_manager_invitations_flow.mmd`, `release_0_11_0_setup_wizard_platform_flow.mmd`, `safety_and_federation_review_operations.mmd`, plus a `release_0_11_0_capability_map.mmd`.
- **Screenshots are real, not just planned:** `bin/docs_screenshots` + `spec/docs_screenshots/**` (e.g. `release_0_11_0_federation_platform_spec.rb`, `release_0_11_0_setup_wizard_spec.rb`) build real host+peer `Platform`/`PlatformConnection`/`StorageConfiguration` fixtures and capture desktop+mobile screenshots, committed under `docs/screenshots/{desktop,mobile}/*.png` with JSON sidecars — covering the setup wizard, platform connections index/editor, host-platform profile, storage configuration, and the federation-review dashboard queue.
- **Gap:** there is no dedicated `PlatformDomain` CRUD controller/view, so there is no screenshot of a domain-management admin UI — matching the gap in §3.
- **System docs worth reading alongside this assessment:** `docs/developers/systems/federation_system.md`, `docs/developers/systems/multi_tenant_platform_runtime.md` (explicitly states isolation is shared-schema/row-scoped, not schema-per-tenant), `docs/platform_organizers/federation_setup_and_activation.md`, `docs/platform_organizers/federation_privacy_and_consent.md`.

---

## 8. Test Coverage Map

| Area | Coverage | Gap |
|---|---|---|
| Domain resolution & isolation | Strong — `spec/requests/better_together/platform_domain_routing_spec.rb`, `platform_domain_resolution_spec.rb`, `multi_platform_isolation_spec.rb`, `spec/middleware/better_together/platform_context_middleware_spec.rb` | No system/browser spec simulating real cross-host navigation |
| Platform/PlatformDomain models | Good — `spec/models/better_together/platform_spec.rb`, `platform_domain_spec.rb`, `platform_cascade_spec.rb` | — |
| Provisioning service | Good — happy path + idempotency + (post PR #1581) steward rename, PlatformDomain auto-creation assertion | No spec for the rake task itself |
| Self-serve billing-gated provisioning (PR #1581) | Request spec covers entitlement gating and redirects | Mocks the provisioning service — doesn't itself assert domain creation end-to-end |
| **Combined "provision → attach subdomain/custom domain → verify isolation" flow** | **None existed prior to this assessment** | Closed for this assessment's purposes by the validated runbook in `docs/production/multi_platform_deployment.md`; a permanent system spec is still recommended (see implementation plan) |
| External OAuth (GitHub) | Deep — 600+ line controller specs, account-linking edge cases | Only GitHub is implemented, so only GitHub is tested |
| Federation (PlatformConnection, OAuth, content pull) | Broad — request/service/model specs across `federation/`, `platform_connections`, transport adapters | Person-level consent gate has no tests because it doesn't exist yet |

---

## 9. Cross-Reference: management-tool's Own 0.11.0 Release Gate

management-tool's `docs/community-engine-release-v0.11.0-plan.md` gates the `v0.11.0` version-file bump purely on a **production deploy matrix** (CI green + `communityengine`/`newfoundlandlabradoronline`/`newcomernavigatornl.ca`/`nlvenues` redeployed and read-only-verified). It does not currently reference the architectural gaps in this document (federation consent gate, missing domain-management UI, inconsistently-scoped billing/C3 models). Recommend adding a pointer from that document to this assessment and to `docs/plans/0.11.0-multi-platform-release-readiness-plan.md` so the deploy-matrix gate and the architecture-completeness gate are both visible to whoever finalizes the release. (Not edited as part of this assessment, since the user scoped deliverables to the community-engine-rails repo — flagged here for follow-up.)

---

## Related Documents

- `docs/production/multi_platform_deployment.md` — the actionable, tested provisioning runbook this assessment produced.
- `docs/plans/0.11.0-multi-platform-release-readiness-plan.md` — the prioritized implementation plan for the gaps identified here.
- `docs/assessments/multi_tenancy_gap_assessment_2026-03-11.md` — superseded by this document; retained for historical context.
- `docs/developers/systems/federation_system.md`, `docs/developers/systems/multi_tenant_platform_runtime.md` — up-to-date developer architecture docs.
- `docs/plans/federation-consent-identity.md` — the tracked plan for the P0 federation-activation blocker.
