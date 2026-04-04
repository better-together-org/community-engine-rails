# JOATU Public Visibility Hardening Plan

## Overview

The JOATU exchange system now has an initial privacy hardening slice in place:

- `BetterTogether::Joatu::Request`
- `BetterTogether::Joatu::Offer`
- `BetterTogether::Joatu::Agreement`

That slice added:

- explicit `privacy` state on JOATU requests, offers, and agreements
- integration with the shared `Privacy` concern
- policy and API scope changes so unrelated authenticated users no longer see private JOATU records by default
- compatibility with the public publishing agreement gate for any public JOATU transition

## Diagrams

- [Mermaid Source](../../diagrams/source/pr_1494_joatu_privacy_visibility_flow.mmd)
- [PNG Export](../../diagrams/exports/png/pr_1494_joatu_privacy_visibility_flow.png)
- [SVG Export](../../diagrams/exports/svg/pr_1494_joatu_privacy_visibility_flow.svg)

## Closed Gap

This closes the earlier gap where JOATU visibility was governed primarily by broad authenticated-access policy scope rather than an explicit public/private model.

The base hardening now ensures:

- requests and offers can be visible more broadly than their participants may expect
- unrelated authenticated users do not automatically see private exchanges
- agreements now participate in the same public/private vocabulary
- JOATU public transitions can be evaluated by the shared publishing-agreement gate

## Remaining Gaps

The JOATU privacy slice is not the full governance answer yet.

Remaining work includes:

- decide which JOATU records should ever be public to the wider community or public internet
- audit JOATU indexing, sharing, matching, and notification behavior against the new privacy model
- confirm whether additional JOATU records need privacy state beyond requests, offers, and agreements
- add any missing governed-agent publication flows once robot-led JOATU publication is a real product behavior

## Required Follow-up

JOATU still needs continued governance review:

1. Decide which JOATU records can ever be public to the wider community or public internet.
2. Re-audit JOATU HTML, JSON:API, matching, and notification surfaces after the privacy model landed.
3. Confirm whether response-link and derived-match visibility needs additional restriction.
4. Extend the same review to any adjacent JOATU records added later.

## Interim Rule

JOATU should still be treated as a governed and sensitive exchange system. Do not expand JOATU public indexing, sharing, or internet-visible publishing beyond the current reviewed slice without another explicit privacy and publishing-agreement audit.
