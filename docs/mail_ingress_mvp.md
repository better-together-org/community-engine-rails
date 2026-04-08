# Inbound mail MVP: multi-tenant routing, privacy, security, and accessibility

This MVP adds a **Community Engine-owned inbound mail relay** that accepts raw RFC 822 mail, records it in Action Mailbox, and routes it through a small set of deterministic aliases.

It is intentionally designed to **fail closed**. The goal is not to accept every possible inbound email shape; the goal is to add a safe, reviewable substrate that protects tenant boundaries and keeps future moderation, governance, and accessibility work tractable.

## What this tranche adds

- a CE relay endpoint at `/inbound-email/relay`
- Action Mailbox ingestion inside the engine
- a namespaced `BetterTogether::ApplicationMailbox` base for host apps
- deterministic alias routing for:
  - `requests+community-slug@tenant-domain`
  - `community+community-slug@tenant-domain`
  - `agent+identifier@tenant-domain`
- persisted intake records in `BetterTogether::InboundEmailMessage`
- tenant-aware routing through `BetterTogether::PlatformDomain`

## Multi-tenant routing model

Host apps should follow the same inheritance pattern they already use for
controllers and mailers:

- `ApplicationController < BetterTogether::ApplicationController`
- `ApplicationMailer < BetterTogether::ApplicationMailer`
- `ApplicationMailbox < BetterTogether::ApplicationMailbox`

That keeps the CE routing contract namespaced while still satisfying Rails'
top-level Action Mailbox entrypoint in each host app.

Recipient **domain** is the tenant boundary.

1. the inbound address domain is resolved through `BetterTogether::PlatformDomain`
2. the matched platform becomes the routing context
3. alias lookup is then constrained to that platform
4. if the tenant/domain cannot be resolved, or if the alias points at a record outside that tenant, the message is stored as **rejected/unresolved**

This prevents cross-tenant leakage when two tenants have similar community names, agent identifiers, or future overlapping aliases.

## Privacy and security posture

### Fail-closed routing

- unknown domains are rejected
- cross-tenant community aliases are rejected
- person fallback for `agent+...` only succeeds when the person has an active membership in the matched platform
- routing does **not** fall back to host/default platforms for inbound mail

### Narrow ingress surface

- the relay endpoint requires HTTP basic auth
- only `message/rfc822` payloads are accepted
- inbound mail is recorded once through Action Mailbox rather than parsed by ad hoc controllers

### Auditable intake records

Each routed or rejected inbound message is persisted with:

- tenant platform (when the domain resolves)
- route kind and status
- sender and recipient metadata
- `Message-ID`
- stored body/subject payloads
- routed record reference when a downstream record is created

That audit trail supports future reviewer queues, moderation workflows, abuse handling, and escalation paths without requiring mailbox re-ingest.

## Accessibility and stakeholder review

This tranche changes backend routing, not an end-user page, so the stakeholder-facing evidence is:

- readable markdown documentation
- rendered Mermaid diagrams in both SVG and PNG formats
- PR-linked image artifacts that can be reviewed without reading Ruby

The diagrams are paired with text so stakeholders who prefer screen readers, low-bandwidth review, or plain-language summaries are not forced to rely on visual-only architecture artifacts.

## Current alias behaviors

| Alias family | Tenant-aware? | Result |
| --- | --- | --- |
| `requests+community-slug@tenant-domain` | Yes | creates a membership request for that tenant community |
| `community+community-slug@tenant-domain` | Yes | stores an inbound community message record |
| `agent+identifier@tenant-domain` | Yes | resolves tenant robot first, then active tenant person membership |
| anything else | Yes | stored as rejected/unresolved |

## Deliberate MVP limits

- no reviewer inbox UI yet
- no end-user alias management UI yet
- no automatic outbound acknowledgements yet
- no external delivery integration beyond the relay endpoint contract

Those are intentionally deferred until the tenant-safe intake substrate is in place.
