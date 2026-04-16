# Public Publishing Agreement Gate System

## Overview

The public publishing agreement gate system is the enforcement layer that prevents Community Engine records from becoming broadly visible until the acting governed agent has accepted the protected `content_publishing_agreement`.

This system extends public visibility beyond plain role-based permission checks. It requires:

- an explicit governed agent
- an accepted publishing agreement
- the existing authorization to change the record
- truthful authorship and audit context for governed publication

The goal is to make public publication a consented, reviewable capability rather than an implicit side effect of organizer or manager privileges.

## Diagrams

- [Mermaid Source](../../diagrams/source/pr_1494_public_publishing_agreement_flow.mmd)
- [PNG Export](../../diagrams/exports/png/pr_1494_public_publishing_agreement_flow.png)
- [SVG Export](../../diagrams/exports/svg/pr_1494_public_publishing_agreement_flow.svg)

## Implemented Foundation

The current implementation adds:

- governed-agent-aware agreement participation for people and robots
- a seeded `content_publishing_agreement`
- a shared `BetterTogether::PublicVisibilityGate`
- model-level validation hooks through `Privacy`, `Publishable`, and platform network visibility
- request/tool context via `Current.governed_agent`
- MCP publication defaults that prefer private drafts over immediate public output

## Current Enforcement Targets

The gate now applies to:

- pages and posts through shared privacy and publishable concerns
- platform network visibility
- JOATU requests, offers, and agreements now that they have explicit privacy state
- MCP post creation and publish flows

## Why This Matters

Before this system, public visibility was effectively granted by existing update permissions and attribute choices such as:

- `privacy: public`
- `published_at`
- platform-level network exposure

That left a governance gap. A person or robot could have enough operational permission to publish without first consenting to the duties and risks of public internet visibility.

The agreement gate closes that gap by making publication depend on:

1. who is acting
2. whether that actor accepted the publishing agreement
3. whether the record is being moved into a publicly exposed state

## Remaining Gaps

This system is not fully complete yet.

Remaining work includes:

- governed-agent acceptance UI beyond current person-led agreement flows
- fully truthful robot-authored page/post rendering in the public UI
- broader audit of all public internet surfaces beyond the currently patched publishing paths
- comment publication review before comments are ever allowed to become public-facing

## QA Notes

This PR slice is mostly governance, schema, policy, and API hardening work.

- **Docs:** present
- **Diagrams:** present
- **Screenshots:** deferred until the governed page/post publishing UI exists as a stable user-facing flow
- **Focused QA:** covered through migration, policy, and API request specs
