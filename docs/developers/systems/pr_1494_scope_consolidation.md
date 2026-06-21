# PR 1494 Scope Consolidation

## Why This Document Exists

PR `#1494` started with a clear governance goal:

- make people and robots first-class governed agents
- make public publishing agreement-gated and auditable
- widen authorship into a broader governed contribution model
- establish a real citation, claim, and evidence foundation
- close JOATU privacy and visibility gaps

That core direction remains sound.

However, the implementation thread also expanded into many adjacent evidence and export surfaces.
Some of that work is useful and should remain in this PR.
Some of it is now lower-leverage than consolidating the primary workflow.

This document defines the cut line so the branch can stop expanding laterally and return to a coherent milestone.

## What Belongs In PR 1494

The following pieces belong together and now form the intended milestone.

### 1. Governed agent foundation

- `Person` and `Robot` as first-class governed actors
- actor-safe agreement participation
- actor-safe authorship and contribution attribution

### 2. Public publishing governance

- seeded public publishing agreement
- agreement-backed public visibility gate
- enforced public publishing restrictions for governed records

### 3. Contribution attribution substrate

- transitional governed contribution model on `better_together_authorships`
- support for roles beyond plain `author`
- JOATU exchange participation recorded as community contribution
- GitHub-backed contribution import foundation

### 4. Evidence foundation

- structured citations
- explicit claims and evidence links
- selector-aware evidence targeting
- bibliography rendering
- exportable evidence records

### 5. JOATU baseline hardening

- privacy added to core JOATU records
- policy visibility hardening
- JOATU contribution and evidence compatibility

### 6. Canonical UI evidence

The PR should keep screenshots and diagrams for the canonical flows that prove the system works:

- governed contribution assignment
- publishing/evidence authoring
- claim evidence browsing
- GitHub citation/contribution import
- JOATU listing/evidence visibility where now implemented

## What Is Supporting But Not Strategic

These slices are valid, but they are no longer the center of gravity for the PR:

- repeated propagation of evidence summaries to more listing surfaces
- repeated propagation of governance bundle links to more surfaces
- more export variants on already-exportable records
- additional browse-only evidence UI outside the core publishing and JOATU flows

They should stay if already landed and stable, but they should not drive the next implementation decisions for this PR.

## What Should Be Deferred

The following work should move to follow-up PRs or issues unless a blocking defect is found.

### Defer: more surface expansion

- additional admin tables and listing surfaces
- more summary widgets on marginal browsing views
- more screenshot packets for minor UI variations

### Defer: export proliferation

- richer governance bundle packaging beyond the current structured bundle
- further CSL / APA / MLA enrichment unless required by a concrete export consumer

### Defer: broad contribution expansion

- governance, finance, moderation, survey, and operational contribution UIs beyond the current substrate
- contribution history/reporting views beyond the current page/post/profile/community/JOATU coverage

### Defer: agreement-edit UI expansion

- first-class JOATU agreement edit/import UI
- more record types with import panels before their editing workflows are actually productized

## Recommended Next Step

Stop widening the PR horizontally.

The next work on top of `#1494` should be one focused consolidation slice:

1. verify the primary governed publishing flow end to end
2. verify the primary JOATU contribution/evidence flow end to end
3. identify any unstable or redundant UI now present in the PR
4. document the deferred follow-up work explicitly

After that, the next feature PR should focus on one of:

- robot-authored page/post publishing as the canonical governed publishing workflow
- a true release-package workflow on top of the governed publishing substrate
- first-class governance and documentation contribution import/reporting beyond content records

## Practical Rule For Continuing

Before adding any new surface in this area, ask:

1. does this change strengthen a canonical workflow already in PR `#1494`?
2. does it introduce a new governance capability rather than another display of the same data?
3. would removing this change make the milestone incomplete?

If the answer is not clearly yes, the work should be deferred.
