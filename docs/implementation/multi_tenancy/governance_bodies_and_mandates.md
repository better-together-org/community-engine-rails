# Governance Bodies And Mandates

**Date:** March 12, 2026  
**Status:** Planning prerequisite  
**Purpose:** Define the governance bodies, stewardship scopes, and corresponding CE role families for federated CE platforms

---

## Summary

This document turns the governance assessment into a decision-ready model for CE.

It defines:

- the governance bodies that exist at platform and community scope
- the responsibilities those bodies hold
- the limits on their authority
- the escalation relationships between them
- the CE role identifiers and permission families that should represent them

This document is intended to sit between:

- the governance assessment
- the RBAC redesign
- the federated tenancy implementation plan

It is the policy source of truth for governance vocabulary before role migration and policy refactor begin.

---

## Core Principle

CE should not flatten all authority into one administrative role.

The governance stack should distinguish:

1. platform stewardship
2. community governance
3. asset stewardship
4. safety and accountability

These are related but not identical forms of authority.

---

## Governance Layers

## 1. Platform Stewardship

### Canonical Body

`platform_stewardship_circle`

### Canonical CE Role Identifier

`platform_steward`

### Mandate

The platform stewardship body governs the CE platform as:

- shared digital infrastructure
- host node in a federated network
- policy and compliance boundary
- operational environment for hosted communities

### Responsible For

- platform-wide policy and default settings
- privacy, compliance, and safety defaults
- peer platform connections and federation policy
- approval of OAuth trust and network relationships
- platform membership stewardship
- stewardship of budgets, staffing, and maintenance priorities for the platform
- oversight of major digital operational changes

### Not Responsible For

- day-to-day governance of every community
- unilateral control over community internal decisions unless platform policy or safety requires intervention
- replacing community governance bodies

### Typical CE Permissions

- `view_platform`
- `edit_platform`
- `manage_platform_settings`
- `manage_platform_members`
- `manage_platform_roles`
- `manage_network_connections`
- `approve_network_connections`
- `manage_federation_auth`
- `manage_content_sharing`
- `manage_mirrors`
- `publish_to_network`

---

## 2. Community Governance

### Canonical Body

`community_governance_body`

This is intentionally generic. Communities may realize it differently:

- council
- circle
- assembly
- elected stewards
- coordinating body

### Canonical CE Role Identifier

`community_governance_council`

This remains the recommended canonical identifier for now because it best preserves the distinction between:

- operational organizers
- formal community decision-makers

The name can be revisited later, but the role should remain distinct from organizer/coordinator roles unless the governance model is intentionally simplified.

### Mandate

The community governance body governs a specific community’s:

- membership rules
- community norms
- internal programming direction
- use of community resources and spaces
- community-specific moderation framework
- delegated representation in relation to the platform

### Responsible For

- admitting and governing community participation
- setting community priorities and norms
- appointing or recognizing operational organizers where relevant
- managing community roles and delegated responsibilities
- stewarding community-specific spaces and assets where assigned

### Not Responsible For

- platform federation policy
- server or deployment operations
- platform-wide compliance and safety defaults
- decisions outside the scope of the specific community

### Typical CE Permissions

- `view_community`
- `edit_community`
- `manage_community_members`
- `manage_community_roles`
- `manage_community_content`
- `invite_members`

---

## 3. Community Operations

### Canonical Body

`community_operations_team`

### Canonical CE Role Identifier

`community_organizer`

### Mandate

Community organizers coordinate the day-to-day functioning of a community.

This is an operational role, not the highest governing authority.

### Responsible For

- scheduling and coordinating activities
- helping onboard members
- carrying out approved community processes
- maintaining community content and participation workflows
- supporting moderators, hosts, and facilitators

### Not Responsible For

- final governance decisions reserved to the community governance body
- platform-level stewardship
- platform federation policy

### Typical CE Permissions

- `view_community`
- `edit_community`
- `manage_community_content`
- `invite_members`

Optional on some communities:

- limited `manage_community_members`

---

## 4. Asset Stewardship

### Canonical Body

`asset_stewardship_circle`

### Canonical CE Role Identifiers

These should be explicit scoped roles rather than implied powers:

- `platform_asset_steward`
- `community_asset_steward`
- `infrastructure_steward`
- `records_steward`
- `facilities_steward`

Not every platform will need all of these as first-class roles immediately. The important architectural decision is that asset stewardship is a separate responsibility family.

### Mandate

Asset stewardship is responsible for the care, continuity, and upkeep of shared assets and procedures.

Assets may be:

- digital
- physical
- procedural
- documentary

### Responsible For

- domains, email, backups, storage, deployment procedures
- records, inventories, documentation, maintenance schedules
- physical resources, equipment, facilities, and shared tools
- operational continuity for stewarded assets

### Not Responsible For

- broad policy decisions beyond the assets they steward
- replacing platform or community governance bodies
- assuming federation power merely because they manage infrastructure

### Typical CE Permissions

These should be implemented as scoped capability families rather than one broad admin role:

- `manage_platform_assets`
- `manage_community_assets`
- `manage_infrastructure_assets`
- `manage_records`
- `view_operational_diagnostics`

Some of these may initially map to platform-level permissions until finer-grained asset models exist.

---

## 5. Safety And Accountability

### Canonical Body

`safety_accountability_circle`

### Canonical CE Role Identifiers

- `platform_safety_steward`
- `community_safety_steward`
- `accountability_steward`

### Mandate

This body handles:

- harms
- reports
- appeals
- misuse of power
- review of safety interventions

It is the closest analogue to an accountability or review branch, but should not be framed as a detached court unless the platform actually wants that structure.

### Responsible For

- reviewing safety cases
- responding to reports and blocks
- handling appeals or escalations
- documenting accountability outcomes

### Not Responsible For

- ordinary day-to-day platform operations
- federation configuration
- replacing platform or community governance except through defined review or emergency authority

### Typical CE Permissions

- `view_safety_cases`
- `manage_safety_cases`
- `manage_person_blocks`
- `review_reports`

---

## Interplay Between Bodies

## Platform Stewards And Community Governance

Platform stewards govern the node.
Community governance bodies govern the community.

That means:

- platform stewards may set binding platform-wide policy and infrastructure constraints
- community governance bodies may govern their own communities within those constraints
- platform stewards should not micromanage community life unless there is:
  - safety risk
  - compliance requirement
  - platform-wide operational need

## Platform Stewards And Asset Stewards

Platform stewards authorize and oversee the stewardship of platform-scale assets.
Asset stewards maintain and care for those assets.

That means:

- asset stewards should not need full platform-steward power to care for infrastructure
- platform stewards should not absorb all asset responsibilities by default

## Community Governance And Community Organizers

Community governance sets direction and legitimacy.
Community organizers coordinate execution.

That means:

- organizer is not a synonym for governance body
- organizer may be delegated broad operational powers without becoming the final decision-making body

## Safety / Accountability And The Other Bodies

Safety and accountability roles provide review and intervention capacity.

That means:

- platform stewards are not the only escalation path
- community governance is not left without recourse if there is internal misuse of power
- asset stewards are not unchecked simply because they hold operational access

---

## Decision Boundaries

## Platform Stewardship Decides

- whether the platform joins or leaves a federation relationship
- default privacy and content-sharing posture
- platform-wide policy and operational norms
- who is entrusted with platform-scale assets

## Community Governance Decides

- who belongs to the community
- community-level priorities, norms, and internal governance
- community-specific programs, spaces, and delegated responsibilities

## Asset Stewardship Decides

- how entrusted assets are maintained and documented
- operational procedures within the stewarded domain
- continuity and upkeep decisions within delegated boundaries

## Safety / Accountability Decides

- harm response outcomes
- case reviews and appeals
- interventions required for safety and accountability

---

## Recommended CE Role Model

### Keep Distinct

- `platform_steward`
- `community_governance_council`
- `community_organizer`
- `platform_asset_steward`
- `community_asset_steward`
- `platform_safety_steward`

### Rename From Current Catalog

- `platform_manager` -> `platform_steward`
- `platform_analytics_viewer` -> `analytics_viewer`

### Keep Distinct Rather Than Merging

- `community_governance_council`
- `community_organizer`

This is the main change from the earlier consolidation idea.

The governance assessment suggests the live elevated community role is real and should not automatically collapse into organizer language.

### Review For Retirement Or Permission-Only Treatment

- `platform_infrastructure_architect`
- `platform_tech_support`
- `platform_quality_assurance_lead`
- `platform_accessibility_officer`
- `community_legal_advisor`
- `community_strategist`

### Review As Specialist Community Roles

- `community_contributor`
- `community_content_curator`
- `community_coordinator`

Some of these may survive as optional specialist roles, but they should not define the core governance stack.

---

## Recommended Permission Families

### Platform Stewardship

- `view_platform`
- `edit_platform`
- `manage_platform_settings`
- `manage_platform_members`
- `manage_platform_roles`

### Federation Stewardship

- `view_network`
- `manage_network_connections`
- `approve_network_connections`
- `manage_federation_auth`
- `manage_content_sharing`
- `manage_mirrors`
- `publish_to_network`
- `review_sync_failures`

### Community Governance

- `view_community`
- `edit_community`
- `manage_community_members`
- `manage_community_roles`
- `manage_community_content`

### Community Operations

- `view_community`
- `edit_community`
- `manage_community_content`
- `invite_members`

### Asset Stewardship

- `manage_platform_assets`
- `manage_community_assets`
- `manage_infrastructure_assets`
- `manage_records`
- `view_operational_diagnostics`

### Safety / Accountability

- `view_safety_cases`
- `manage_safety_cases`
- `manage_person_blocks`
- `review_reports`

---

## Transition Guidance

## Immediate Naming Decisions

Lock now:

- `platform_steward` as the canonical replacement for `platform_manager`
- `community_governance_council` as a distinct governance role
- `community_organizer` as a distinct operational role

Defer until later:

- whether `community_member` should become `member`
- whether specialist community roles remain first-class or become permission bundles

## Migration Rule

Role migration should preserve the distinction between:

- platform stewardship
- community governance
- community operations

Do not merge these into one simplified admin/organizer tier merely because the current live roster is small.

## Live-Roster Interpretation

The current live data should be read as:

- evidence that the platform/community split is real
- evidence that governance concentration is high
- not evidence that the system should collapse role layers

---

## Open Questions

1. Should host-community governance and non-host-community governance share the same role identifier?
2. Do asset stewardship roles belong at platform scope only, or also at community scope by default?
3. Does safety/accountability remain one body or split into platform and community layers?
4. Should `community_coordinator` survive as a middle operational role, or collapse into `community_organizer`?

---

## Dependencies

This document should inform:

- `federated_rbac_reassessment_and_coverage_plan.md`
- `schema_per_tenant_implementation_plan.md`
- future role identifier migrations
- future policy refactor and permission-family design
