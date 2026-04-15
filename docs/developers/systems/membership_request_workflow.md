# Membership Request Workflow

## Overview

Community membership requests provide a bounded alternative to direct invitations on invitation-only platforms. When enabled at the **platform** level for the host community, or at the **community** level for an individual community, visitors can discover and submit a request without needing an invitation code first.

The request stays community-scoped:

- visitors submit a request to a specific community
- community reviewers manage the queue
- approval creates either a direct membership or a follow-up invitation, depending on whether the requester already has an account

## Visual Flow

```mermaid
flowchart TD
  subgraph Discovery["Visitor discovery + intake"]
    A[Private platform sign-up page] --> B{Invitation available?}
    B -->|No| C[Invitation-required interstitial]
    C --> D{Platform or host community allows membership requests?}
    D -->|Yes| E[Embedded host-community membership request form]
    D -->|No| F[No membership request intake shown]
    E --> G[Public membership request submission]
  end

  subgraph Intake["Community membership request intake"]
    G --> H[Joatu::MembershipRequest created for target community]
    H --> I[Request appears in community membership request queue]
  end

  subgraph Review["Community review UI"]
    I --> J[Community manager opens queue or request detail]
    J --> K{Decision}
    K -->|Approve unauthenticated visitor| L[Create community invitation]
    K -->|Approve logged-in person| M[Create person community membership]
    K -->|Decline| N[Close membership request]
  end

  subgraph Followup["Post-review outcome"]
    L --> O[Visitor receives invitation and can register]
    M --> P[Membership becomes active immediately]
    N --> Q[Queue reflects declined state]
    O --> R[Invitation acceptance creates membership]
  end
```

**Diagram Files:**
- [Mermaid Source](../../diagrams/source/membership_request_workflow.mmd)
- [PNG Export](../../diagrams/exports/png/membership_request_workflow.png)
- [SVG Export](../../diagrams/exports/svg/membership_request_workflow.svg)

## Enablement Rules

- **Platform toggle**: `Platform#allow_membership_requests` enables the membership-request entry point for the host platform's primary community.
- **Community toggle**: `Community#allow_membership_requests` enables intake for that specific community.
- **Effective rule**: intake is enabled when either the community allows requests directly or its primary platform allows requests for the host-community path.
- **Registration discoverability**: the sign-up interstitial only renders the request form when the platform still requires invitations and a valid invitation is not already present.

## Backend Workflow

1. A visitor submits `Joatu::MembershipRequest` for a community.
2. The request appears in the community membership request queue.
3. A reviewer approves or declines it.
4. Approval branches:
   - **unauthenticated visitor**: create a `CommunityInvitation`
   - **authenticated requester**: create a `PersonCommunityMembership`
5. Decline closes the request without broadening access.

## Review UI

### Registration interstitial with request form

![Registration interstitial with membership request form](../../screenshots/desktop/membership_request_registration_interstitial.png)

### Membership request review queue

![Membership request review queue](../../screenshots/desktop/membership_request_review_queue.png)

### Membership request review detail

![Membership request review detail](../../screenshots/desktop/membership_request_review_detail.png)

Mobile captures are generated alongside the desktop variants in `docs/screenshots/mobile/`.

## Review entry points added by the remediation pass

The original `0.11.0` workflow added the request queue and detail view, but the later remediation work made those review surfaces easier to find from normal stewardship screens.

### Host dashboard review queue

![Host dashboard membership review queue](../../screenshots/desktop/membership_review_host_dashboard_queue.png)

- platform managers can now reach membership review from the host dashboard
- the queue summarizes open-request counts, recent requester activity, and a direct review action
- this closes the “known URL only” gap that left review work hard to discover

### Community page review shortcut

![Community page membership review shortcut](../../screenshots/desktop/membership_review_community_shortcut.png)

- community managers now get a reviewer-only panel on the community page itself
- the panel shows the open-request count and links directly to the review queue
- this keeps request handling connected to the community-management surface people already use

## Reviewer notification digest behavior

The remediation also changed reviewer notifications so repeated request bursts do not pile up as one notification per request forever.

```mermaid
flowchart TD
  A[New membership request submitted] --> B[Find community and platform reviewers]
  B --> C[Count open requests for this community in the last 15 minutes]

  C -->|Fewer than 3 open requests| D[Keep per-request notification path]
  D --> E[Send MembershipRequestSubmittedNotifier to each reviewer]

  C -->|3 or more open requests| F[Switch to digest path]
  F --> G[Check whether the last digest email for this reviewer and community is older than 30 minutes]
  G --> H[Remove unread per-request notifications for this community]
  H --> I[Replace any unread digest notification for this reviewer and community]
  I --> J[Create a fresh MembershipRequestDigestNotifier]
  J --> K{Email cooldown cleared?}
  K -->|Yes| L[Send one digest email with the community review link]
  K -->|No| M[Keep the in-app digest only]

  E --> N[Reviewer opens the community review queue]
  L --> N
  M --> N
```

**Diagram files:**
- [Mermaid Source](../../diagrams/source/membership_review_notification_digest_flow.mmd)
- [PNG Export](../../diagrams/exports/png/membership_review_notification_digest_flow.png)
- [SVG Export](../../diagrams/exports/svg/membership_review_notification_digest_flow.svg)

### What the digest flow changes

1. Individual notifications are still used for small volumes of requests.
2. Once a community accumulates **3 or more** open requests inside a **15 minute** window, unread per-request notifications are collapsed into one digest per reviewer.
3. Digest emails are rate-limited so the same reviewer does not receive a new digest email for the same community more often than every **30 minutes**.
4. The digest keeps the same review destination: the community membership review queue.

## Privacy and Authorization Boundaries

- public visitors may only **create** requests when the target community intake is enabled
- request review remains a privileged community-management workflow
- the registration page does not expose general admin tooling, only the bounded request form
- approval expands access through the normal invitation or membership pipeline rather than bypassing it
