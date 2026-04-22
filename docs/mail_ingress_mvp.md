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

CE does **not** define or install a global `::ApplicationMailbox` anymore. The
host app owns that root constant and opts into inbound mail explicitly by
subclassing the CE base.

Recipient **domain** is the tenant boundary.

1. the inbound address domain is resolved through `BetterTogether::PlatformDomain`
2. the matched platform becomes the routing context
3. alias lookup is then constrained to that platform
4. if the tenant/domain cannot be resolved, or if the alias points at a record outside that tenant, the message is stored as **rejected/unresolved**

This prevents cross-tenant leakage when two tenants have similar community names, agent identifiers, or future overlapping aliases.

## Privacy and security posture

### Shared content-security intake and hold gate

- every inbound email now enters a **content-security screening gate** before any downstream membership-request creation or future routing action
- the gate builds shared-contract payloads for:
  - the email body + metadata (`from`, `to`, `subject`, `Message-ID`, attachment manifest)
  - each attachment as its own content item with tenant-scoped metadata
- CE stores the returned contract records on `BetterTogether::InboundEmailMessage` and only allows downstream routing when the aggregate verdict is `clean` or `monitor`
- when the scanner returns `review_required`, `restricted`, `quarantined`, `blocked`, or raises an error/unconfigured condition, CE **holds** the message and does not create downstream records

### Shared orchestrator dependency

- the prototype expects a stable command in `BETTER_TOGETHER_CONTENT_SAFETY_ORCHESTRATOR_COMMAND`
- that command should point at the shared management-tool orchestrator entrypoint, for example a checked-in wrapper around `scripts/content_safety_scanner_orchestrator.py`
- if the command is absent or fails, this prototype intentionally **fails closed** and keeps the inbound message held for review

### Fail-closed routing

- unknown domains are rejected
- cross-tenant community aliases are rejected
- person fallback for `agent+...` only succeeds when the person has an active membership in the matched platform
- routing does **not** fall back to host/default platforms for inbound mail

### Narrow ingress surface

- the relay endpoint requires HTTP basic auth
- only `message/rfc822` payloads are accepted
- inbound mail is recorded once through Action Mailbox rather than parsed by ad hoc controllers
- the host app must provide `ApplicationMailbox < BetterTogether::ApplicationMailbox` to activate the routing contract

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
- no stable mainline home for the shared scanner command yet; this prototype stores contract records and holds mail, but merge/mainline work still needs the shared scanner path to become a supported dependency

Those are intentionally deferred until the tenant-safe intake substrate is in place.

## Mainline merge requirements

This implementation currently lives only in `tmp/worktrees/ce-mail-ingress-mvp/...`, because the inspected CE main tree still does not expose a canonical `app/mailboxes/` / Action Mailbox ingress seam.

To merge/mainline it honestly, CE still needs:

1. the Action Mailbox controller, mailbox classes, model, migrations, and specs from this prototype promoted into the canonical CE tree
2. a **stable shared scanner entrypoint** for `BETTER_TOGETHER_CONTENT_SAFETY_ORCHESTRATOR_COMMAND` (vendored wrapper, gem, engine integration, or another supported dependency) instead of a worktree-only path
3. host-app install/upgrade guidance for the new inbound-email and screening migrations
4. a reviewer-facing queue or admin workflow that can release held mail after screening, because this tranche only implements intake + hold, not the full moderation UI
