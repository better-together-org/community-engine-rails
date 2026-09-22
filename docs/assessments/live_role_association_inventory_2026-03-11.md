# Live Role Association Inventory

**Snapshot captured:** March 11-12, 2026  
**Purpose:** Document which live CE role identifiers are actually referenced by invitations and memberships on live CE-based platforms

---

## Scope

This snapshot covers the live CE-based apps that were running and serving production domains at capture time:

| Platform | Host / App | Primary domain |
|----------|------------|----------------|
| Community Engine | `bts-3` / `communityengine` | `communityengine.app` |
| Newcomer Navigator NL | `bts-5` / `newcomernavigatornl.ca` | `newcomernavigatornl.ca` |
| NL Venues | `bts-4` / `nlvenues` | `nlvenues.com` |
| Newfoundland Labrador Online | `bts-5` / `newfoundlandlabradoronline` | `newfoundlandlabrador.online` |

Excluded from the live snapshot:

- `bts-1` / `newcomernavigatornl.ca`: domain configured but app not running at snapshot time
- `bts-1` / `wayfinder`: domain configured but app not running at snapshot time
- `bts-5` / `communityengine`: running but no live domains attached
- `bts-5` / `nlvenues`: not deployed and no live domains attached

---

## Method

For each included app, the snapshot counted live references to each `BetterTogether::Role` identifier across:

- `better_together_person_platform_memberships.role_id`
- `better_together_person_community_memberships.role_id`
- `better_together_invitations.role_id`
- `better_together_platform_invitations.platform_role_id`
- `better_together_platform_invitations.community_role_id`

Roles were marked:

- `in use` when at least one live row referenced that role identifier
- `unused` when the role existed in `better_together_roles` but had zero references in the live tables above

This is a reference-usage snapshot, not a policy-capability audit.

---

## Cross-Platform Summary

### In Use On Every Included Live Platform

- `community_member`
- `community_governance_council`
- `platform_manager`

### In Use On Some But Not All Live Platforms

- `community_contributor`
  - in use on `communityengine` and `nlvenues`
- `community_content_curator`
  - in use on `newcomernavigatornl.ca` only
- `community_coordinator`
  - in use on `newcomernavigatornl.ca` only
- `platform_developer`
  - in use on `communityengine`, `newcomernavigatornl.ca`, and `nlvenues`
- `platform_analytics_viewer`
  - in use on `newcomernavigatornl.ca` only

### Unused On Every Included Live Platform

- `community_facilitator`
- `community_legal_advisor`
- `community_strategist`
- `platform_accessibility_officer`
- `platform_infrastructure_architect`
- `platform_quality_assurance_lead`
- `platform_tech_support`

### Schema / Seed Drift

- `newfoundlandlabradoronline` has 14 role identifiers instead of 15.
- It is missing `platform_analytics_viewer`.
- Its live membership rows also did not expose the newer active/pending status counts the same way as the other included apps, which suggests schema or deployment drift relative to the other live CE platforms.

---

## Per-Platform Inventory

## Community Engine

**Host / app:** `bts-3` / `communityengine`  
**Seeded role identifiers present:** 15

### In Use

| Identifier | Resource type | Total refs | Live reference shape |
|------------|---------------|------------|----------------------|
| `community_member` | `BetterTogether::Community` | 80 | 16 community memberships, 6 generic invitations, 18 platform invitations as community role |
| `community_governance_council` | `BetterTogether::Community` | 26 | 8 community memberships, 4 generic invitations, 1 platform invitation as community role |
| `community_contributor` | `BetterTogether::Community` | 10 | 3 community memberships, 2 platform invitations as community role |
| `platform_developer` | `BetterTogether::Platform` | 8 | 2 platform memberships, 2 platform invitations as platform role |
| `platform_manager` | `BetterTogether::Platform` | 6 | 2 platform memberships, 1 platform invitation as platform role |

### Unused

- `community_content_curator`
- `community_coordinator`
- `community_facilitator`
- `community_legal_advisor`
- `community_strategist`
- `platform_accessibility_officer`
- `platform_analytics_viewer`
- `platform_infrastructure_architect`
- `platform_quality_assurance_lead`
- `platform_tech_support`

### Notes

- The live references are heavily concentrated in `community_member`.
- Community role usage is broader than platform role usage.
- The platform membership rows observed here were pending rather than active in this snapshot.

## Newcomer Navigator NL

**Host / app:** `bts-5` / `newcomernavigatornl.ca`  
**Seeded role identifiers present:** 15

### In Use

| Identifier | Resource type | Total refs | Live reference shape |
|------------|---------------|------------|----------------------|
| `community_member` | `BetterTogether::Community` | 824 | 171 community memberships, 241 platform invitations as community role |
| `community_governance_council` | `BetterTogether::Community` | 26 | 9 community memberships, 4 platform invitations as community role |
| `platform_manager` | `BetterTogether::Platform` | 22 | 6 platform memberships, 5 platform invitations as platform role |
| `community_content_curator` | `BetterTogether::Community` | 10 | 3 community memberships, 2 platform invitations as community role |
| `community_coordinator` | `BetterTogether::Community` | 10 | 5 community memberships |
| `platform_developer` | `BetterTogether::Platform` | 8 | 2 platform memberships, 2 platform invitations as platform role |
| `platform_analytics_viewer` | `BetterTogether::Platform` | 2 | 1 active platform membership |

### Unused

- `community_contributor`
- `community_facilitator`
- `community_legal_advisor`
- `community_strategist`
- `platform_accessibility_officer`
- `platform_infrastructure_architect`
- `platform_quality_assurance_lead`
- `platform_tech_support`

### Notes

- `community_member` dominates this platform’s live role associations by a large margin.
- This is the only included live platform where `platform_analytics_viewer` is actually referenced.
- This is also the only included live platform where `community_content_curator` and `community_coordinator` are referenced.

## NL Venues

**Host / app:** `bts-4` / `nlvenues`  
**Seeded role identifiers present:** 15

### In Use

| Identifier | Resource type | Total refs | Live reference shape |
|------------|---------------|------------|----------------------|
| `community_member` | `BetterTogether::Community` | 32 | 7 community memberships, 9 platform invitations as community role |
| `community_governance_council` | `BetterTogether::Community` | 20 | 8 community memberships, 2 platform invitations as community role |
| `platform_manager` | `BetterTogether::Platform` | 14 | 4 platform memberships, 3 platform invitations as platform role |
| `community_contributor` | `BetterTogether::Community` | 4 | 1 community membership, 1 platform invitation as community role |
| `platform_developer` | `BetterTogether::Platform` | 4 | 1 platform membership, 1 platform invitation as platform role |

### Unused

- `community_content_curator`
- `community_coordinator`
- `community_facilitator`
- `community_legal_advisor`
- `community_strategist`
- `platform_accessibility_officer`
- `platform_analytics_viewer`
- `platform_infrastructure_architect`
- `platform_quality_assurance_lead`
- `platform_tech_support`

### Notes

- Live role usage is narrow and looks structurally closer to `communityengine` than to `newcomernavigatornl.ca`.
- `community_contributor` is present but low-volume.

## Newfoundland Labrador Online

**Host / app:** `bts-5` / `newfoundlandlabradoronline`  
**Seeded role identifiers present:** 14

### In Use

| Identifier | Resource type | Total refs | Live reference shape |
|------------|---------------|------------|----------------------|
| `community_member` | `BetterTogether::Community` | 15 | 15 community memberships |
| `community_governance_council` | `BetterTogether::Community` | 1 | 1 community membership |
| `platform_manager` | `BetterTogether::Platform` | 1 | 1 platform membership |

### Unused

- `community_content_curator`
- `community_contributor`
- `community_coordinator`
- `community_facilitator`
- `community_legal_advisor`
- `community_strategist`
- `platform_accessibility_officer`
- `platform_developer`
- `platform_infrastructure_architect`
- `platform_quality_assurance_lead`
- `platform_tech_support`

### Notes

- This is the narrowest live role footprint of the included apps.
- No live invitation references were observed in the counted invitation tables.
- This platform is missing `platform_analytics_viewer` entirely from `better_together_roles`.

---

## Implications For RBAC Cleanup

The live data supports a much smaller practical role footprint than the seeded catalog.

### Seeded And Clearly Live

- `community_member`
- `community_governance_council`
- `platform_manager`

### Seeded And Live Only On Some Platforms

- `community_contributor`
- `community_content_curator`
- `community_coordinator`
- `platform_developer`
- `platform_analytics_viewer`

### Seeded But Unused Everywhere In This Live Snapshot

- `community_facilitator`
- `community_legal_advisor`
- `community_strategist`
- `platform_accessibility_officer`
- `platform_infrastructure_architect`
- `platform_quality_assurance_lead`
- `platform_tech_support`

This reinforces the earlier RBAC planning conclusion:

- the seeded catalog is broader than live usage
- `platform_manager` remains one of the few consistently live platform roles
- any federation-aware RBAC cleanup should start from the live-used identifiers, not from the full seeded catalog

### Identifier Rename Signal

The live footprint supports a narrower first-pass cleanup:

- `community_governance_council` is the only elevated community identifier used on every included live platform
- `community_facilitator` is unused everywhere in this live snapshot
- `community_coordinator` is only used on `newcomernavigatornl.ca`

That supports keeping `community_governance_council` distinct as the formal host-community governance role while reviewing:

- `community_facilitator`
- `community_coordinator`

as consolidation candidates into:

- `community_organizer`

The stronger rename signal at platform scope is:

- `platform_manager` should be reviewed as a rename candidate to `platform_steward`

Any rename work should include:

- data migration for live memberships and invitations
- seed compatibility during transition
- fixture and spec helper updates, especially where `:as_platform_manager` is baked into the test suite
