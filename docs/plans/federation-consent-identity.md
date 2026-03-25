# Plan: Federation Consent Gate + Person Identity Architecture

**Tracking issue:** better-together-org/community-engine-rails#1407
**Target version:** v0.11.1 (blocks any PlatformConnection activation)
**Status:** Design complete — implementation pending

---

## Background

PR #1215 shipped the full federation infrastructure (PlatformConnection, FederationAccessToken,
FederatedContentPullJob, FederatedSeedAttributes, LinkedSeedIngestService, PersonLink,
PersonLinkedSeed, all migrations). That work is live on main.

The original authorship opt-in plan (`federation-authorship-opt-in.md`) addressed only
whether an author's *name* should appear on federated content — it missed the prior consent
question: **should content leave the platform at all without the author's knowledge?** It
also proposed a JSONB byline blob, which creates two separate person records on destination
platforms with no path to merge them.

This plan supersedes that design with:
1. **Unified consent gate** — `federate_content` setting on Person controls both content
   export and identity export. No content leaves without opt-in.
2. **Federated Person stubs** — a proper minimal Person record is created on the destination
   platform, UUID-preserved from the source, so attribution is coherent and mergeable.
3. **PersonLink claim flow** — native persons on destination platforms can claim federated
   stubs, consolidating their identity across platforms.

---

## Why No PlatformConnection May Be Activated Until v0.11.1

The current `FederatedSeedAttributes` exports content with *no* author identity. On the
destination, posts/pages/events arrive as authorless orphans:
- No deletion path if the author deletes their account
- No correction or update mechanism
- No consent — the author never agreed to their content leaving
- Violates ActivityPub's mandatory `attributedTo` requirement (industry consensus)

This is a hard operational gate. Platform managers must not activate any connection until
v0.11.1 is deployed.

---

## Architecture

### 1. Person-Level Consent: `federate_content` Setting

```ruby
# Person#settings (Storext):
federate_content: false  # default — explicit opt-in required
```

- `false` (default): person's content is **excluded from the export cursor entirely** —
  not federated to any connected platform
- `true`: content is eligible for export AND a minimal person stub is always exported
  alongside it

The toggle unifies consent: "my content AND my identity can be shared with connected
platforms." Authors who opt in understand both will be shared.

For system-owned content (no personal creator): the platform identity is used as fallback
attribution.

---

### 2. Export: Federated Person Block in `FederatedSeedAttributes`

When `creator&.federate_content?` is true, the export payload includes a `federated_person`
block:

```ruby
{
  title: '...', content: '...',
  federated_person: {
    id:                creator.id,              # UUID — preserved on destination
    identifier:        creator.identifier,
    display_name:      creator.display_name,
    description:       creator.bio.present? ? creator.bio.to_plain_text : nil,
    profile_image_url: creator.profile_image_url(size: 300),
    source_platform: {
      id:         source_platform.id,
      identifier: source_platform.identifier,
      name:       source_platform.name,
      url:        source_platform.resolved_host_url
    }
  }
}
```

When `federate_content?` is false or creator is nil: the record is **excluded from the
export cursor** — the `federated_person` key is absent AND the content record itself is
not included in the payload.

---

### 3. Ingest: Federated Person Upsert with PersonLink Pre-Check

When `LinkedSeedIngestService` (or `FederatedContentPullJob`) receives a seed with a
`federated_person` block:

**Step 1: PersonLink pre-check**
```ruby
link = PersonLink.active
  .where(platform_connection: connection)
  .where(source_person_id: federated_person[:id])
  .first
```

- If found with `target_person`: use `target_person` as `creator_id`. **No stub created.**
  The content appears under the native platform person immediately.

**Step 2: Stub upsert (when no active PersonLink)**
```ruby
person = Person.find_or_initialize_by(id: federated_person[:id])
person.assign_attributes(
  display_name:        federated_person[:display_name],
  identifier:          federated_person[:identifier],
  description:         federated_person[:description],
  federated_origin:    true,
  federation_provenance: {
    source_platform_id:   federated_person.dig(:source_platform, :id),
    source_platform_url:  federated_person.dig(:source_platform, :url),
    source_platform_name: federated_person.dig(:source_platform, :name),
    profile_image_url:    federated_person[:profile_image_url],
    federated_at:         Time.current.iso8601
  }
)
person.save!
```

- Stub persons have no `User` record and no `PersonPlatformMembership`
- Profile avatar rendered from `federation_provenance['profile_image_url']` (remote URL,
  no re-upload needed)
- UUID is preserved — the same person federating from Platform A will resolve to the same
  stub record on every sync

**Step 3: Suggestion**
After stub creation, `FederatedPersonSuggestionService` fuzzy-matches native persons by
`identifier` or `display_name` and creates a pending claim notification for potential
matches and platform stewards.

---

### 4. New DB Columns (people table only)

```ruby
add_column :better_together_people, :federation_provenance, :jsonb
add_column :better_together_people, :federated_origin, :boolean, default: false, null: false
add_column :better_together_people, :merged_into_person_id, :uuid, null: true
add_index  :better_together_people, :federated_origin
add_index  :better_together_people, :merged_into_person_id,
           where: "merged_into_person_id IS NOT NULL"
add_foreign_key :better_together_people, :better_together_people,
                column: :merged_into_person_id, on_delete: :nullify
```

No new PersonLink columns — `link_origin` already exists via Storext settings. Add
`'federation_claim'` as a valid value to the `PersonLink::LINK_ORIGINS` constant.

---

### 5. PersonLink Extension: Federation Claim Origin

```ruby
# app/models/better_together/person_link.rb

# Add 'federation_claim' to valid link_origin values

def source_person_must_belong_to_source_platform
  # Stubs have no platform membership on Platform A — validated differently
  return if federation_claim_link?
  return if member_of_platform?(source_person, platform_connection&.source_platform)
  errors.add(:source_person, 'must belong to the source platform')
end

def validate_federation_claim_source
  return unless federation_claim_link?
  return if source_person&.federated_origin? &&
            source_person.federation_provenance['source_platform_id'] ==
              platform_connection&.source_platform_id&.to_s
  errors.add(:source_person, 'must be a federated stub from the connection source platform')
end

def federation_claim_link?
  link_origin == 'federation_claim'
end
```

**Federation claim flow:**
1. Native person on Platform B sees stub and recognizes it as themselves
2. They initiate a claim → creates a PersonLink:
   - `link_origin: 'federation_claim'`
   - `source_person: stub` (UUID-preserved Platform A identity)
   - `target_person: native_person`
   - `status: pending`
3. Verification: system queries Platform A to confirm UUID identity via federation token
4. Upon verification → PersonLink `status: active` → `PersonFederationMergeJob` fires

---

### 6. Person Federation Merge Job

On PersonLink activation (for `federation_claim` links):

```ruby
# PersonFederationMergeService
# - Reassigns Post/Page/Event creator_id from stub → native person
# - Copies federation_provenance to native person's record (for provenance UI)
# - Marks stub: merged_into_person_id = native_person.id (soft-archived)
# - Future syncs use PersonLink directly (no new stubs)
```

---

### 7. Profile Change Propagation

When a person with `federate_content: true` updates their profile:

```ruby
FEDERATED_PROFILE_FIELDS = %w[display_name bio identifier].freeze

after_commit :enqueue_profile_federation_update, on: [:update],
  if: -> { saved_changes.keys.intersect?(FEDERATED_PROFILE_FIELDS) && federate_content? }
# ActiveStorage attachment changes trigger via separate attachment callbacks
```

`FederatedPersonProfileUpdateJob`:
1. Finds all active platform connections where this person's home platform is the source
2. For each connection: POSTs updated person stub to destination
3. Destination: `PUT /better_together/federation/person_stubs/:uuid` → upserts stub record

New endpoints:
- `GET  /better_together/federation/person_stubs/:uuid` — fetch current stub (source platform)
- `PUT  /better_together/federation/person_stubs/:uuid` — upsert stub (destination platform)

---

### 8. The Three Identity Scenarios

**Scenario A — Pre-federation linking (accounts linked via Joatu before content arrives)**

PersonLink already active → ingestor uses `target_person` directly. No stub created.
The person's content appears under their native Platform B identity seamlessly.

**Scenario B — Federation first, claiming later**

No PersonLink → stub created with UUID preserved. Suggestion notification fires.
Native person claims → `PersonFederationMergeJob` → all content reassigned.

**Scenario C — Native person initiates linking proactively**

Person uses "Connect your profile" UI in settings → Joatu/OAuth challenge → PersonLink
created. If stub already exists, merge job runs. Future content uses Scenario A path.

---

### 9. Provenance UI

| Surface | What user sees |
|---|---|
| Stub profile page on Platform B | "This person publishes on [Platform A]" + "Is this you? Claim this profile" CTA |
| Native person profile (post-claim) | "Also publishes on [Platform A]" badge; all federated content appears under their profile |
| Person settings page | "Privacy & Federation" section: `federate_content` toggle + "Your linked profiles" list |
| Platform steward admin | "Federated person stubs" panel: unresolved stubs, match suggestions, manual claim initiation |
| Content cards / show pages | `_federation_badge` partial: "From [Platform A]" — visible when `creator.federated_origin?` and not yet claimed |
| Post-claim | Content cards show native person's avatar + name; federation badge removed |

i18n keys: `better_together.federation.*` in en, fr, es, uk.

---

## Acceptance Criteria

### Person settings
- [ ] `federate_content` boolean on `Person#settings` via Storext (default: `false`)
- [ ] Person edit form: toggle under "Privacy & Federation" section
- [ ] i18n key: `better_together.people.settings.federation.federate_content`

### Export (`FederatedSeedAttributes`)
- [ ] When `federate_content?` is false or creator is nil: record excluded from export cursor
- [ ] When `federate_content?` is true: `federated_person` block present with all fields
- [ ] Unit specs: opt-out → record absent; opt-in → `federated_person` present; nil creator → absent

### Ingest (`LinkedSeedIngestService`)
- [ ] PersonLink pre-check: active link → use `target_person`; no link → stub upsert
- [ ] Migration: `federation_provenance jsonb`, `federated_origin boolean` (indexed),
      `merged_into_person_id uuid` (nullable FK) on `better_together_people`
- [ ] Stub: UUID preserved, `federated_origin: true`, `federation_provenance` populated
- [ ] Stub has no `User` record, no `PersonPlatformMembership`
- [ ] Upsert: updates display_name, description, profile_image_url on every sync
- [ ] After stub creation: `FederatedPersonSuggestionService` fires

### PersonLink extension
- [ ] `'federation_claim'` added to valid `link_origin` values
- [ ] `source_person_must_belong_to_source_platform` relaxed for claim links
- [ ] `validate_federation_claim_source` validates stub provenance matches connection
- [ ] Claim flow: PersonLink `pending` → verified → `active` → merge job

### Person Federation Merge
- [ ] `PersonFederationMergeService`: reassigns content, copies provenance, archives stub
- [ ] `PersonFederationMergeJob`: async wrapper; idempotent

### Profile propagation
- [ ] `after_commit` on profile fields + attachment changes → `FederatedPersonProfileUpdateJob`
- [ ] Job pushes updated stub to all active connections
- [ ] `PUT /better_together/federation/person_stubs/:uuid` endpoint on destination
- [ ] `GET /better_together/federation/person_stubs/:uuid` endpoint on source

### Provenance UI
- [ ] `_federation_badge` partial for federated content (post/page/event)
- [ ] Stub profile page: claim CTA for authenticated native persons
- [ ] Native person profile: "Also publishes on" badge after claim
- [ ] Person settings: "Your linked profiles" list
- [ ] Platform steward: stubs panel with match suggestions
- [ ] i18n: en, fr, es, uk for all new keys

---

## Required Tests

- [ ] `FederatedSeedAttributes` unit: opt-out excludes record; opt-in includes `federated_person`
- [ ] `LinkedSeedIngestService` spec: PersonLink pre-check paths; stub upsert; UUID preservation
- [ ] `Person` model: `federate_content` defaults false; can be toggled
- [ ] `PersonLink` model: `federation_claim` origin validates correctly; relaxed platform membership check
- [ ] `PersonFederationMergeService` spec: content reassignment; stub archival; idempotency
- [ ] `FederatedPersonProfileUpdateJob` spec: propagates changes to all active connections
- [ ] System spec: opt-in → publish post → federated seed includes `federated_person`
- [ ] System spec: stub created on ingest → claim → content appears under native person

---

## New Services and Jobs

| Class | Purpose |
|---|---|
| `PersonFederationMergeService` | Reassign federated content from stub → native; copy provenance; mark stub merged |
| `PersonFederationMergeJob` | Async wrapper for MergeService |
| `FederatedPersonProfileUpdateJob` | Push profile updates to all connected platforms after Person changes |
| `FederatedPersonSuggestionService` | Fuzzy-match stub against native persons → pending claim suggestions |

---

## Stakeholders

| Name | Role |
|------|------|
| Rob Polowick | Product lead — privacy + identity design decisions |
| Platform managers | Must not activate PlatformConnections until v0.11.1 deployed |
| Community Engine users | People whose content and identity may be federated |
