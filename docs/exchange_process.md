# Joatu Exchange: Process Overview

This document captures the current exchange system (Offers, Requests, Agreements, Matches, Response Links, Notifications) in a diagram-ready format.

## Core Entities

- Offer: Something a person can provide.
  - Key fields: creator, name, description, categories, optional address, target (polymorphic), status (open/matched/fulfilled/closed), urgency (low/normal/high/critical), agreements, response links.
  - Behaviors: translated name/description, friendly slug, categorizable, view metrics, matches on create.
- Request: Something a person needs.
  - Same shape and behaviors as Offer.
- Agreement: Confirmation linking one Offer and one Request.
  - Status: pending/accepted/rejected.
  - Validations: Offer/Request target_type and target_id must align if present.
  - Side effects: on create → mark both sides matched if open; notify both creators. On accept → close Offer and Request; notify both creators. On reject → notify both creators.
- ResponseLink: Explicit link between a source (Offer or Request) and its opposite-type response (Request or Offer).
  - Constraints: opposite types only; source must be respondable (open or matched).
  - Side effects: mark source matched if it was open; notify (Offer→Request case notifies the offer creator).
- Matchmaker: Service that finds opposite-type matches.
  - Criteria: opposite type, status=open, category overlap (if any), same target_type; same target_id if present, else both nil; exclude same creator; exclude records that already have outgoing response links; distinct results.

## Actors & Permissions

- Creator: Creates/edits/closes own Offers/Requests; initiates Agreements; can accept/reject Agreements where they are a participant.
- Counterparty: Accepts/rejects Agreements they are party to.
- Platform manager: Elevated actions (policy-gated).
- Guests: Limited visibility; full exchange features require authentication.

## State Machines

- Offer/Request status
  - open → matched: when a ResponseLink is created to/from it, or when an Agreement is created (callback tries to move open to matched).
  - matched → closed: when an Agreement is accepted (both sides closed).
  - open/matched → fulfilled: manual transition (separate from Agreement acceptance).
  - Any → closed: manual close possible (explicit enum state).
- Agreement status
  - pending: on creation.
  - pending → accepted: participant accepts; auto-closes Offer and Request.
  - pending → rejected: participant rejects; Offer/Request remain as-is.

## Automatic Matching & Notifications

- When an Offer or Request is created, the system queries for matches using Matchmaker and sends a “New match found” notification to the creators of both sides for each match.
- Viewing an Offer/Request automatically marks its related match notifications as read for the current person. Viewing an Agreement marks its agreement-related notifications as read.

## Primary Flows

1) Create Listing
- User creates an Offer or Request (valid name, description, ≥1 category; optional address; optional target polymorphic).
- Status=open.
- System runs Matchmaker; sends match notifications to involved creators; matches appear on listing pages (and Hub aggregates).

2) Direct Response (explicit link)
- From Offer → Respond with Request: Prefilled Request form from Offer details; builds nested ResponseLink Offer→Request if source respondable; on create: mark Offer matched; notify offer creator via ResponseLink.
- From Request → Respond with Offer: Prefilled Offer form from Request details; nested ResponseLink Request→Offer if source respondable (or controller fallback after save); on create: mark Request matched.

3) Agreement Lifecycle
- Initiation: Participant creates an Agreement linking a specific Offer and Request.
- Creation: Agreement status=pending; mark both sides matched (if open); notify both creators.
- Decision:
  - Accept: Agreement accepted → Offer.status=closed; Request.status=closed; notify both creators.
  - Reject: Agreement rejected → Offer/Request statuses unchanged (remain open or matched); notify both creators.

## Permutations & Branch Points

- Direction: Offer-first or Request-first (symmetric).
- Target scope: target_type only; target_type + target_id; or both nil (general). Matching respects exactness: nil-only pairs with nil; id pairs require equality.
- Multiple Agreements: Multiple pending possible; acceptance of any one closes both sides, preventing further matches (Matchmaker filters on status=open).
- Response constraints: ResponseLink only if source is open or matched; otherwise blocked.
- Notifications: Match notifications on listing creation; ResponseLink one-way notify (Offer→Request); Agreement creation/status change notifications to both creators; auto mark-as-read on related page view.

## Useful Routes (authenticated exchange scope)

- Exchange hub: GET /:locale/bt/exchange
- Offers: CRUD; GET /exchange/offers/:id/respond_with_request
- Requests: CRUD; GET /exchange/requests/:id/respond_with_offer; GET /exchange/requests/:id/matches
- Agreements: CRUD; POST /exchange/agreements/:id/accept; POST /exchange/agreements/:id/reject

## Diagram Notes

- Use swimlanes for Offer Creator, Request Creator, System (optional in Mermaid; can represent via subgraphs).
- Group flows: Create Listing, Direct Response, Agreement Lifecycle, Notification Read, and State Transitions.
- Show key decision nodes: respondable source? agreement accepted? target alignment validation.

