# JOATU Public Visibility Hardening Plan

## Current Gap

The JOATU exchange models currently do not use the shared `Privacy` concern:

- `BetterTogether::Joatu::Request`
- `BetterTogether::Joatu::Offer`
- `BetterTogether::Joatu::Agreement`

As a result, their visibility is governed primarily by policy scope and authenticated-access rules rather than an explicit public/private publishing model.

This leaves an important governance gap:

- requests and offers can be visible more broadly than their participants may expect
- there is no publishing-agreement gate for JOATU surfaces today
- agreements can be exposed to participants and stewards without a unified public/private vocabulary
- JOATU remains outside the new public publishing agreement enforcement unless it adopts explicit privacy state

## Required Follow-up

JOATU needs its own dedicated schema and policy slice:

1. Add explicit privacy fields to requests, offers, and agreements where appropriate.
2. Decide which JOATU records can ever be public to the wider community or public internet.
3. Apply the shared publishing-agreement gate to any JOATU transition that enables broad public visibility.
4. Preserve participant-only and steward-only visibility for sensitive exchange records by default.
5. Re-audit JOATU HTML, JSON:API, matching, and notification surfaces after the privacy model lands.

## Interim Rule

Until JOATU privacy is implemented, JOATU should be treated as a governed but not yet fully public-safe exchange system. Do not expand JOATU public indexing, sharing, or internet-visible publishing without first landing explicit privacy state and publishing-agreement enforcement.
