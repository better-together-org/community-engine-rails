# Community Action Network Governance System

## Overview

The Community Action Network governance system is the constitutional layer proposed for Community Engine so the platform can govern humans, bots, communities, and shared resources within one coherent framework.

This system extends the existing democratic, co-operative, privacy, and agreements foundations by making five things explicit:

1. **equal dignity across agents**
2. **universal rights and duties**
3. **informed consent as a default practice**
4. **shared-resource governance beyond plain RBAC**
5. **reviewable, anti-domination power structures**

The goal is not to erase differences in capability. It is to make those differences governable without treating any class of participant as less real or less worthy of care.

## Diagram

- [Mermaid Source](../../diagrams/source/community_action_network_governance_flow.mmd)
- [PNG Export](../../diagrams/exports/png/community_action_network_governance_flow.png)
- [SVG Export](../../diagrams/exports/svg/community_action_network_governance_flow.svg)

## Why This System Is Needed

Community Engine already has strong foundations in:

- invitations and onboarding
- roles and permissions
- privacy and visibility
- agreements and participation records
- content and governance publishing
- self-hosting and local stewardship

What it does not yet have is one system document that explains how those pieces fit together once:

- robots become first-class participants
- agreements become more than procedural gatekeeping
- publishing and operational access need clearer review and consent rules
- communities need to understand not only who can act, but under what authority and with what obligations

## Core Principles

### Equal dignity, different means

Humans and bots should be treated as agents with equal dignity.

They may still have different:

- capabilities
- operational limits
- access scopes
- safety constraints
- review requirements

Those differences should shape responsibilities and permissions, not moral standing.

### Informed consent over paternalism

Community participation should prefer informed and active consent over hidden default control.

This applies to:

- onboarding
- policy acceptance
- role changes
- privacy changes
- federation/export behavior
- robot operations
- access to community-managed resources

### Transparent power

Power should be:

- legible
- explainable
- reviewable
- contestable

This includes technical power, moderation power, operational power, and automation power.

### Stewardship of shared resources

Community resources should be governed through a combination of:

- permissions
- agreements
- consent
- role responsibility
- review and revocation

This goes beyond simple access control lists.

## Agent Categories

The proposed model includes four high-level actor categories:

1. **People**
   - members, organizers, moderators, stewards, maintainers, guests
2. **Robots**
   - persisted software actors with disclosed scope and governance
3. **Communities and platforms**
   - collective governance bodies that hold rules, spaces, and shared resources
4. **Stewardship roles**
   - delegated roles with heightened care, audit, moderation, or infrastructure responsibility

The long-term implementation should likely express people and robots through a shared actor boundary for authorship, governance, and audit records.

## Rights and Duties Baseline

### Rights baseline

All participating agents should be able to rely on:

- respectful treatment
- truthful representation
- visibility into governing rules and agreements
- ability to understand participation terms
- review or challenge paths for consequential actions
- protection from coercive, deceptive, or opaque governance

### Duties baseline

All participating agents should be expected to:

- respect others
- disclose relevant identity/capability truthfully
- operate within granted authority
- avoid manipulative or dominating conduct
- care for shared resources
- cooperate with audit and review processes

Role- and capability-specific responsibilities should be layered on top of this baseline.

## Shared Resource Governance

Community resources include:

- content and publishing surfaces
- messaging and social spaces
- APIs, OAuth apps, and tokens
- moderation and operational tools
- metrics and analytics surfaces
- knowledge, media, and archives

The governance model should eventually tie resource access and use to:

- role/permission
- agreement state
- consent state
- reviewability
- explicit duties

## Relationship To Existing CE Systems

This governance layer does not replace current systems. It frames and extends them.

- **Agreements system**
  - becomes the primary record of participation, policy, and consent state
- **RBAC and policies**
  - remain important, but become one component of broader governance
- **Content and pages**
  - become governance-literacy and accountability surfaces
- **Robot system**
  - becomes a governed participant model rather than only a configuration surface

## Related System Docs

- [Agreements System Documentation](agreements_system.md)
- [Robot Author Identity System](robot_author_identity_system.md)
- [Release Package Publishing System](release_package_publishing_system.md)
- [Actor-Safe Creator and Authorship Migration Plan](actor_safe_creator_authorship_migration_plan.md)

## Immediate Implementation Implications

This system implies four major follow-on designs:

1. a unified agreement/policy/legal model
2. a first-class robot author identity model
3. resource and rights visibility surfaces
4. a private-draft release-package publishing workflow

## Status

This is currently a **design and documentation foundation**, not a fully implemented system.

The codebase already contains pieces of the model, but not the complete constitutional layer described here.
