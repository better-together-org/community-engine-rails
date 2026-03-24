# Federated Governance Stack Assessment

**Snapshot captured:** March 11-12, 2026  
**Purpose:** Assess the current BTS infrastructure roster and live CE platform roster against the emerging platform-stewardship and community-governance model

---

## Scope

This assessment compares:

- the current BTS infrastructure roster
- the current live CE platform roster
- the visible host-platform and host-community governance shape on each live CE instance

It uses the current federated governance direction:

- platform stewardship governs the platform as infrastructure and as a network node
- community governance governs the life of a specific community
- asset stewardship should be a distinct responsibility layer
- safety and accountability should not be collapsed into generic admin power

For privacy reasons, this repo document summarizes live rosters rather than copying the full private host-community membership lists into version control. The raw local extracts remain on this machine in:

- `/home/rob/bts-cloud/Collectives/Better Together Solutions/n8n-templates/bts/management-tool/tmp/live-governance-audit`

---

## Ideal Form

The target governance stack implied by the current planning work is:

1. `platform_steward`
   - governs the platform instance as shared infrastructure and network participant
2. community governance body
   - governs the host community and any other communities according to their own mandate
3. asset stewardship roles
   - explicitly responsible for digital infrastructure, facilities, records, procedures, and shared resources
4. safety / accountability roles
   - review harm, disputes, misuse of power, and appeals

The important separation is:

- platform governance is not the same thing as community governance
- asset stewardship is not the same thing as general administration
- federation makes platform-level responsibility more important, not less

---

## BTS Infrastructure Roster

### Current Practical CE Hosting Topology

| Host | Current CE relevance | Assessment against ideal form |
|------|----------------------|-------------------------------|
| `bts-0` | primary ops host, n8n, observability, AI stack, central workspace | still a strong coordination hub; stewardship appears operationally centralized |
| `bts-3` | live `communityengine` | clear CE host node |
| `bts-4` | live `nlvenues` | clear CE host node |
| `bts-5` | live `newcomernavigatornl.ca`, live `newfoundlandlabradoronline`, plus collaboration services | mixed-purpose node; governance and asset stewardship boundaries likely need to be made more explicit |
| `bts-1` | CE app names present but stopped at snapshot time | indicates hosting drift and roster ambiguity |

### Infrastructure Assessment

Current BTS infrastructure still looks more like a stewarded operator fleet than a federated stewardship commons with explicit bodies.

Strengths:

- hosting is distributed across multiple CE-capable nodes
- the live CE app roster is not concentrated on a single production host
- there is enough host separation to support platform-level autonomy

Gaps:

- no visible machine-readable steward roster per server
- no distinct asset-stewardship roster for servers, domains, storage, backups, or shared operations
- the same BTS operational center still appears to coordinate most cross-platform maintenance
- stopped duplicate app instances suggest platform roster maintenance drift

Conclusion:

The infrastructure is technically distributed, but stewardship visibility is still centralized and informal.

---

## Live CE Platform Roster

### Included Live Instances

| Platform | Host / App | Primary domain | Host platform role shape | Host community role shape |
|----------|------------|----------------|--------------------------|---------------------------|
| Community Engine | `bts-3` / `communityengine` | `communityengine.app` | 4 platform memberships | 19 host-community memberships |
| Newcomer Navigator NL | `bts-5` / `newcomernavigatornl.ca` | `newcomernavigatornl.ca` | 9 platform memberships | 169 host-community memberships |
| NL Venues | `bts-4` / `nlvenues` | `nlvenues.com` | 5 platform memberships | 11 host-community memberships |
| Newfoundland Labrador Online | `bts-5` / `newfoundlandlabradoronline` | `newfoundlandlabrador.online` | 1 platform membership | 16 host-community memberships |

### Excluded From This Live Governance Snapshot

- `bts-1` / `newcomernavigatornl.ca`: not running at snapshot time
- `bts-1` / `wayfinder`: not running at snapshot time
- `bts-5` / `communityengine`: running without live domains
- `bts-5` / `nlvenues`: not deployed

### Platform Roster Assessment

The live roster supports the platform/community split concept:

- each live instance has a platform membership layer
- each live instance has a host community membership layer
- the people in platform leadership and host community leadership overlap heavily, but the layers are still distinct

That means the architecture is already closer to the intended governance split than a flat admin system would be.

The main issue is not whether the split exists.
The issue is whether its roles are named, scoped, and activated cleanly enough to support federated governance.

---

## Cross-Platform Social Graph

This section is an inference from live platform and host-community rosters, not a claim that CE already has a formal cross-platform social graph model.

### Strong Cross-Platform Stewardship Overlap

The most visible shared stewardship node across all included live apps is:

- `Rob` / `rob`
  - `platform_manager` on all four included live platforms
  - `community_governance_council` on all four included host communities

Other repeated cross-platform actors include:

- `Katja Moehl`
  - present across `communityengine`, `newcomernavigatornl.ca`, and `nlvenues`
  - role mix spans platform and community layers
- `Jordan Knee`
  - present across `communityengine` and `nlvenues`
  - role mix changes by platform

### Assessment

The current live graph shows:

- strong human overlap across platform stewardship and host-community governance
- a small recurring steward network across multiple CE instances
- limited visible separation between platform-level and community-level leadership bodies in practice

This is not inherently wrong for an early or relational ecosystem, but it does mean:

- stewardship concentration is high
- succession and delegation risk are high
- the governance stack is still more person-centered than body-centered

---

## Per-Platform Governance Shape

## Community Engine

### Host Platform

- platform identifier: `community-engine`
- platform privacy: `public`
- platform memberships:
  - `platform_manager`: 2
  - `platform_developer`: 2

### Host Community

- host community identifier: `community-engine`
- host community privacy: `public`
- host community memberships:
  - `community_governance_council`: 2
  - `community_contributor`: 2
  - `community_member`: 15
- statuses:
  - `pending`: 18
  - `active`: 1

### Assessment

- clear separation exists between platform and host-community layers
- the governing body is small and concentrated
- almost all host-community memberships are still pending, which weakens the practical meaning of membership as a governance signal

## Newcomer Navigator NL

### Host Platform

- platform identifier: `wayfinder`
- platform privacy: `public`
- platform memberships:
  - `platform_manager`: 6
  - `platform_developer`: 2
  - `platform_analytics_viewer`: 1

### Host Community

- host community identifier: `wayfinder`
- host community privacy: `public`
- host community memberships:
  - `community_governance_council`: 5
  - `community_content_curator`: 2
  - `community_member`: 162
- statuses:
  - `pending`: 157
  - `active`: 12

### Assessment

- this is the largest visible host-community graph in the live CE roster
- the platform stewardship body is larger than on the other platforms
- the host community is broad, but activation is still low relative to total membership rows
- this instance is the clearest case for distinguishing:
  - platform stewardship
  - community governance
  - content stewardship

## NL Venues

### Host Platform

- platform identifier: `nl-venues`
- platform privacy: `public`
- platform memberships:
  - `platform_manager`: 4
  - `platform_developer`: 1

### Host Community

- host community identifier: `nl-venues`
- host community privacy: `private`
- host community memberships:
  - `community_governance_council`: 3
  - `community_contributor`: 1
  - `community_member`: 7
- statuses:
  - `pending`: 11

### Assessment

- governance appears compact and easier to reason about than the larger newcomer instance
- platform leadership and host-community leadership remain closely linked
- a private host community plus small leadership roster may make this a good candidate for piloting clearer steward vs member distinctions

## Newfoundland Labrador Online

### Host Platform

- platform identifier: `newfoundland-labrador-online`
- platform privacy: `public`
- platform memberships:
  - `platform_manager`: 1

### Host Community

- host community identifier: `newfoundland-labrador-online`
- host community privacy: `private`
- host community memberships:
  - `community_governance_council`: 1
  - `community_member`: 15
- status shape:
  - status values were not present in the same way as the other live apps

### Assessment

- this is the most fragile governance stack in the live roster
- stewardship appears effectively single-person at both platform and host-community layers
- several host-community member records look synthetic or placeholder-like rather than clearly live human community members
- this platform most clearly fails the “body-centered stewardship” goal and should be treated as needing maintenance and governance hardening

---

## Asset Stewardship Assessment

The ideal model needs explicit asset stewardship roles, but the live CE roster does not currently show a distinct asset-stewardship layer.

What is visible:

- platform managers / future platform stewards
- host-community governance roles
- a few content-related roles

What is not visibly represented as a distinct live role layer:

- infrastructure stewardship
- digital asset stewardship
- facilities or physical asset stewardship
- records / procedure stewardship

Conclusion:

Asset stewardship is currently implicit inside platform leadership and community leadership rather than represented as a first-class governance body.

That is a structural gap if the ecosystem is meant to support:

- physical infrastructure
- digital infrastructure
- shared procedures
- federated platform operations

---

## Fit Against The Ideal Governance Model

| Dimension | Current fit | Assessment |
|-----------|-------------|------------|
| platform vs community separation | medium to strong | the two membership layers exist and matter |
| platform stewardship as its own body | weak to medium | role exists in practice, but is still named as admin/manager and heavily person-centered |
| community governance as its own body | medium | the host-community governance role is clearly used |
| asset stewardship | weak | not visible as a distinct live role layer |
| safety / accountability separation | weak | not visible in the live roster data gathered here |
| federation readiness | medium | platform-level stewardship concept is viable, but role concentration and roster drift remain risks |
| succession / resilience | weak | too much visible dependence on a small recurring human set |

---

## Main Findings

1. The platform/community split still makes sense and is already reflected in the live data model.
2. The current live ecosystem is steward-heavy, but the steward network is concentrated in a small recurring group.
3. `community_governance_council` functions in practice as the main host-community governance body across the live roster.
4. `platform_manager` functions in practice as the main platform-level stewardship role, even though the name no longer fits the intended stewardship framing.
5. Asset stewardship is a real conceptual need, but not yet represented as a visible live role layer.
6. `newfoundlandlabradoronline` is the clearest outlier for maintenance, governance fragility, and platform drift.

---

## Recommendations

### Immediate

- rename `platform_manager` toward `platform_steward`
- keep platform and community memberships separate
- do not collapse community governance into platform stewardship
- add NLO to the normal CE maintenance and upgrade cadence

### Near-Term

- define an explicit asset-stewardship role family
- decide whether `community_governance_council` remains a formal governance-body identifier or becomes a broader community-stewardship role
- audit why so many live memberships remain `pending`

### Structural

- create a steward roster for BTS infrastructure itself, not just CE app data
- reduce person-centered stewardship concentration by assigning explicit bodies or circles to:
  - platform stewardship
  - host-community governance
  - asset stewardship
  - safety / accountability

---

## Related Documents

- `docs/implementation/multi_tenancy/federated_rbac_reassessment_and_coverage_plan.md`
- `docs/assessments/live_role_association_inventory_2026-03-11.md`
