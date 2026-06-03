# Actor-Safe Creator and Authorship Migration Plan

## Overview

Community Engine currently models most creator and authorship relationships through `BetterTogether::Person`.

That is accurate for the current product, but it is not sufficient for the future community action network model where:

- robots can become first-class governed participants
- robot-authored release packages and posts need truthful attribution
- agreements and resource access need to reflect broader governed-agent participation

This document defines the safest migration path from the current person-bound model toward an actor-safe model.

## Current State

### Creator model

The `Creatable` concern currently defines:

- `belongs_to :creator, class_name: 'BetterTogether::Person', optional: true`

This pattern appears across many CE models through direct `creator_id` columns and person foreign keys.

Examples visible in the schema include:

- agreements
- pages
- posts
- conversations
- events
- content blocks
- seeds and seed plantings
- reports and metrics reports
- invitations and wizard steps
- geography and infrastructure records

### Authorship model

`BetterTogether::Authorship` currently defines:

- `belongs_to :author, class_name: 'BetterTogether::Person'`
- `belongs_to :authorable, polymorphic: true`
- optional `creator_id` tracking of the acting person who added or removed an author

This means:

- authored content can only point at people as authors
- author-notification logic assumes person recipients
- content workflows cannot truthfully represent a robot as the authoring subject

### Agreements participation model

`BetterTogether::AgreementParticipant` currently defines:

- `belongs_to :person, class_name: 'BetterTogether::Person'`

So platform agreement acceptance is still person-bound as well.

## Migration Constraints

An actor-safe migration has to preserve several existing truths:

1. current person-based behavior must keep working throughout the transition
2. deletion, audit, and moderation flows already depend on person foreign keys
3. notifications and current session state still assume `Current.person`
4. not every `creator_id` in the schema should necessarily become actor-polymorphic immediately
5. agreement participation semantics should not be widened until rights, duties, and consent semantics are clearer

Because of those constraints, a single-step polymorphic rewrite would be too risky.

## Recommended Migration Sequence

### Phase 1: Shared governed-agent identity seam

This phase is now started through the `GovernedAgent` concern.

Goals:

- give `Person` and `Robot` a shared identity vocabulary
- create a stable code seam for future actor-safe changes
- avoid schema churn while rights and governance semantics are still being refined

### Phase 2: Introduce actor-safe authorship schema alongside current authorship

Recommended direction:

- add `author_type` beside `author_id` on `better_together_authorships`
- backfill existing records with `author_type = 'BetterTogether::Person'`
- update associations to support a polymorphic `author` interface while preserving person helpers
- keep notification delivery guarded so only valid recipient models are notified

Important rule:

do not remove the existing person assumptions in one step. Add compatibility paths first.

### Phase 3: Introduce actor-safe creator tracking selectively

Not every `creator_id` needs the same treatment at the same time.

The migration should likely be split into tiers:

#### Tier A: publishing and content records

Highest priority for actor-safe migration:

- pages
- posts
- authorships
- possibly content blocks directly involved in authored page composition

These are the records needed for truthful robot-authored release packages and posts.

#### Tier B: governance and agreement records

Potential next targets after semantics are clearer:

- agreement participants
- safety agreements and safety notes/actions
- policy acknowledgement records

These should not be widened until consent, review, and role semantics are defined more explicitly.

#### Tier C: infrastructure and operational records

Lower-priority or possibly person/steward-specific forever:

- wizard steps
- operational reports
- some metrics reports
- some infrastructure records

Some of these may remain explicitly person-created, depending on the product meaning of those records.

### Phase 4: Introduce actor-aware UI and audit surfaces

Once publishing/authorship records become actor-safe:

- render robot authors truthfully in pages/posts
- expose governed-agent labels and identity summaries
- show which actions were performed by a person versus a robot
- preserve clear human review and override visibility

### Phase 5: Revisit agreement participation

Only after actor identity, rights, duties, and robot-operation semantics are clearer should CE consider broadening agreement participation beyond people.

That later step may involve:

- `participant_type` plus `participant_id`
- or a new governed-agent join model with explicit role metadata

That decision should be made together with unified agreement lifecycle work.

## Proposed First Implementation Targets

The first schema-backed implementation should focus on:

1. `better_together_authorships`
2. `better_together_pages`
3. `better_together_posts`

Reason:

these models unlock truthful robot-authored release packages with the least amount of unrelated governance churn.

## Backfill and Compatibility Rules

When the actor-safe schema work begins, it should follow these rules:

- backfill existing person rows first
- keep old person-based helpers during transition
- do not break current views/helpers expecting `Person`
- add compatibility methods instead of forcing a big-bang refactor
- update deletion and audit flows explicitly, not implicitly

## Status

This is a migration-planning document, not an active schema change.

The product now has:

- governance foundation docs
- governed-agent identity helpers for `Person` and `Robot`

The actual creator/authorship schema migration remains future work and should follow the phased plan above.

