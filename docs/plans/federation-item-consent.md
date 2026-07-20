# Plan: Federation Item Consent (Tri-State) + Federation Hub

**Tracking issue:** TBD — file a new tracking issue before merging (deliberately separate from
better-together-org/community-engine-rails#1407; do not fold this work into that issue)
**Target version:** v0.11.1+
**Status:** Phases 1–4 implemented (data model, enforcement, per-item UI, Federation Hub with
activity feed); Phase 5 (this doc + notifier) in progress

---

## Background

Federation shipped on `release/0.11.0-notes` (PR #1215 and follow-ups) with two independent,
coarse consent gates:

1. **Connection-level** (`PlatformConnection` + `PlatformConnectionFederationPolicy` concern):
   per-connection × per-content-type booleans (`share_posts`, `share_pages`, `share_events`).
   Set by whoever manages the connection (`manage_network_connections`/`approve_network_connections`).
2. **Person-level** (`Person#federate_content`, a Storext boolean, default `false`): a single
   global switch. If true, *all* of that person's public content is eligible for export to
   *every* connection that allows the content type. If false, none of it is — with no way to
   vary this per item or per connection.

There was no way for a content creator to say "federate my content in general, but not this
specific event," and no dashboard surfacing federation status to anyone but platform managers
(via the `manage_platform`-gated Host Dashboard's federation-review tab).

This plan is deliberately **separate** from `docs/plans/federation-consent-identity.md`
(tracking #1407), which addresses a different axis — federated **Person identity** (UUID-preserved
stub records, claim/merge flow, profile propagation). The two plans share one read dependency
(`Person#federate_content` remains the `platform_default` fallback boolean for both) but govern
different decisions: #1407 decides whether/how a *Person* is exported; this plan decides whether
a *content item* is exported, and gives every person a place to see that status.

---

## What shipped

### Phase 1 — Data model + enforcement

- New concern `BetterTogether::Federatable` (`app/models/concerns/better_together/federatable.rb`),
  modeled on the existing `Privacy` concern: a real `federation_visibility` column + native `enum`
  with three values —
  - `platform_default` (default) — defers entirely to the existing connection-type-toggle +
    creator's global `federate_content` boolean (today's behavior, unchanged)
  - `federate` — explicit per-item opt-in, bypasses the creator's global `federate_content`
    setting
  - `no_federate` — hard per-item opt-out, wins even if the creator opted in globally and the
    connection allows the content type
- Included in `Post`, `Page`, `Event` via three idempotent migrations using the new
  `bt_federation_visibility` column-definition helper (`lib/better_together/column_definitions.rb`,
  modeled on `bt_privacy`).
- `Content::Block` is explicitly **out of scope** — it has no federation attributes today and
  isn't part of the export/mirror pipeline at all; adding it would be a materially larger,
  separate effort.
- Enforcement lives entirely in
  `app/services/better_together/content/federated_content_export_service.rb`: `consent_scoped`
  was renamed to `federation_consent_scoped` and now layers the tri-state on top of the existing
  creator-preference check. `FederationScopeAuthorizer` and `Content::FederatedContentAuthorizer`
  were **not** changed — both remain connection/scope-level only, which is correct; item-level
  consent is deliberately a lower layer.

### Phase 2 — Policy + per-item UI

- No new Pundit policy action needed: `federation_visibility` rides on the same `update?` gate as
  every other editable attribute, exposed via `Federatable#extra_permitted_attributes` (same
  pattern as `Privacy`).
- New `federation_visibility_field` helper in `app/helpers/better_together/form_helper.rb`
  (modeled on `contributor_display_visibility_field`/`comment_settings_select_field`), wired into
  the Post/Page/Event forms next to their existing privacy controls.
- i18n across en/fr/es/uk: a shared `attributes.federation_visibility_list.*` enum-label key
  (same convention as the existing `privacy_list`), plus `federatable.labels`/`federatable.hints`.

### Phase 3 — Federation Hub (read-only MVP)

- New top-level nav destination (`app/controllers/better_together/federation_hub_controller.rb`),
  a sibling to `HubController`/`Joatu::HubController` — **not** a Host Dashboard tab, since it
  needs to be reachable by any signed-in person, not just platform managers with
  `manage_platform`.
- `FederationHubPolicy`: `show?`/`activity?` open to any authenticated person;
  `manage_connections_section?` gates the admin card inline (same
  `manage_network_connections`/`approve_network_connections` check the Host Dashboard's
  federation-review tab already uses).
- `FederationHub::PersonalContentSummaryService` — per-person counts by `federation_visibility`
  and recent items, discovering content classes dynamically via `Federatable.included_in_models`
  rather than a hardcoded allowlist (so a future federatable model is picked up automatically).
- `FederationHub::ConnectionHealthSummaryService` — thin wrapper over the existing
  `PlatformConnectionSyncTracking` predicates, summarizing rather than duplicating the Host
  Dashboard's connection review table (the admin card links out to it).

### Phase 4 — Activity feed

- `PlatformConnectionSyncTracking`'s `mark_sync_started!`/`mark_sync_succeeded!`/
  `mark_sync_failed!` now record `BetterTogether::Activity` rows directly (`Activity.create!`,
  not the `trackable.create_activity` convenience method — `PlatformConnection` deliberately does
  not include `TrackedActivity`/`PublicActivity::Model`, since it has no `privacy` column and
  connection audit activity must never leak into the public, `ActivityPolicy::Scope`-filtered
  feed).
- `FederationHub::ActivityFeedService` queries `Activity` directly, bypassing
  `ActivityPolicy::Scope` entirely — gating visibility via the controller's
  `manage_connections_section?`/`current_person` checks instead. Combines the signed-in person's
  own federatable-content activity with connection activity (when permitted). Direction filtering
  (incoming/outgoing relative to the host platform) is expressed as a SQL subquery so Kaminari
  pagination stays index-backed.
- New `activity` action/route/views with content-type and (admin-only) direction filters.

### Phase 5 — Per-connection selection matrix

Ships the item's exception to the tri-state: "federate this item to Platform A but not
Platform B," layered on top of (not replacing) `federation_visibility`.

- New `better_together_federation_content_grants` join table (idempotent migration):
  polymorphic `federatable` + `belongs_to :platform_connection`, a `status` enum
  (`allowed`/`denied`, default `allowed`), unique on `(federatable_type, federatable_id,
  platform_connection_id)`.
- `BetterTogether::FederationContentGrant` model, `Federatable` concern gains
  `has_many :federation_content_grants`, `federation_content_type_key`,
  `federation_grant_status_for(connection)`, and a
  `federation_content_grants_by_connection=` bulk setter (upserts/destroys rows keyed by
  connection id; `'platform_default'` removes the grant).
- `FederatedContentExportService#federation_consent_scoped` precedence, evaluated in order:
  1. `no_federate` always excludes, regardless of any per-connection grant.
  2. A `denied` grant for the requesting connection excludes the item, regardless of the
     creator's global opt-in or `federate` visibility.
  3. An `allowed` grant for the requesting connection includes the item even when the
     creator's global preference or `platform_default` visibility would otherwise exclude it.
  4. Falls back to the existing tri-state/creator-preference logic when no grant exists for
     that connection.
- Per-item UI: `federation_content_grants_field` (in `form_helper.rb`) renders one row per
  active `PlatformConnection` that allows the item's content type
  (`federation_connections_for`), using `select_tag` with bracketed nested param names
  (`post[federation_content_grants_by_connection][<connection_id>]`) rather than
  `accepts_nested_attributes_for`, since grants are a sparse keyed map, not an ordered
  collection.
- i18n across all 4 locales (`en`, `es`, `fr`, `uk`): grant status labels, hint, and field
  label under `better_together.federatable`.

---

## Explicitly deferred (not in this plan's scope)

- **`Content::Block` federation** — would require new export/mirror/ingest plumbing from
  scratch; out of scope.
- **Notifications for federation status changes** — see the notifier added alongside this doc;
  kept minimal (one notifier, one trigger point) rather than a full notification-preferences
  surface.

---

## Interaction with #1407

Purely additive. #1407's identity/attribution work operates on a different axis — whether and
how a *Person* is exported — and should compose with, not replace, `federation_consent_scoped`'s
per-item gate. If #1407 later introduces per-connection identity-export toggles, its authors
should review this plan doc to confirm the two layers remain independent.

---

## Key files

| Concern | File |
|---|---|
| Tri-state concern | `app/models/concerns/better_together/federatable.rb` |
| Enforcement | `app/services/better_together/content/federated_content_export_service.rb` |
| Per-item form field | `app/helpers/better_together/form_helper.rb` (`federation_visibility_field`) |
| Per-connection grant model | `app/models/better_together/federation_content_grant.rb` |
| Per-connection grant migration | `db/migrate/20260719020000_create_better_together_federation_content_grants.rb` |
| Per-connection grant form field | `app/helpers/better_together/form_helper.rb` (`federation_content_grants_field`) |
| Hub policy | `app/policies/better_together/federation_hub_policy.rb` |
| Hub controller | `app/controllers/better_together/federation_hub_controller.rb` |
| Hub summary services | `app/services/better_together/federation_hub/*_summary_service.rb` |
| Activity feed | `app/services/better_together/federation_hub/activity_feed_service.rb` |
| Sync activity recording | `app/models/concerns/better_together/platform_connection_sync_tracking.rb` |

## Required tests (shipped)

- `spec/services/better_together/content/federated_content_export_service_spec.rb` — tri-state ×
  creator-opt-in matrix, plus the per-connection grant precedence matrix (denied overrides
  opt-in, allowed overrides opt-out/`no_federate` never overridden, grant scoped to a
  different connection is ignored)
- `spec/models/better_together/{post,page,event}_spec.rb` — `Federatable` concern coverage
  (tri-state + grant setter/getter)
- `spec/models/better_together/federation_content_grant_spec.rb` — validations, uniqueness
  scope, default status
- `spec/requests/better_together/{posts,pages,events}_controller_spec.rb` — per-item field
  renders and persists, per-connection grant row renders and persists
- `spec/policies/better_together/federation_hub_policy_spec.rb`
- `spec/services/better_together/federation_hub/*_spec.rb`
- `spec/requests/better_together/federation_hub_controller_spec.rb`
- `spec/models/better_together/platform_connection_spec.rb` — sync-activity recording

## Stakeholders

| Name | Role |
|------|------|
| Rob Smith | Product lead — privacy + consent design decisions |
| Platform managers | Configure connection-level content-type sharing; see the Hub's admin section |
| Community Engine members | People whose content may be federated; see the Hub's personal panel |
