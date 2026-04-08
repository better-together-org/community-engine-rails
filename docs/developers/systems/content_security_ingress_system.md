# Content Security Ingress System

This document describes the first Community Engine content-security ingress slice for:

- inbound mail received through Action Mailbox
- Active Storage uploads served through CE-controlled proxy paths
- Action Text embedded attachments that must respect release state before rendering

The design follows BTS values around privacy, accountability, and safety:

- newly received content stays private or held until it is releasable
- known-dangerous or uncertain mail is held before downstream routing
- AI ingestion remains separate from human publication and review
- evidence stored in CE stays minimal and review-oriented rather than becoming a new surveillance archive

## Overview

The current implementation adds a shared CE-side content-security substrate with three concrete ingress points:

1. **Inbound mail relay and routing**
   - `POST /inbound-email/relay`
   - `ActionMailbox::InboundEmail`
   - `BetterTogether::InboundEmailRoutingService`
   - `BetterTogether::ContentSecurity::MailScreeningService`
   - `BetterTogether::InboundEmailMessage`
2. **Active Storage blob enrollment and release gating**
   - `BetterTogether::ContentSecurity::Subject`
   - `BetterTogether::ContentSecurity::AttachmentSubjectSync`
   - `BetterTogether::ContentSecurity::BlobAccessPolicy`
   - CE proxy routes for blob and representation serving
3. **Action Text embedded attachment controls**
   - rich-text validation for unsupported attachments
   - embedded blob subject synchronization
   - unreleased attachment filtering before render

## Inbound mail flow

The new inbound-mail seam gives CE a canonical place to receive mail from the BTS router before promoting it into application behavior.

### Entry point

- `POST /inbound-email/relay`
- requires HTTP basic auth with the configured inbound mail password
- requires `message/rfc822`
- stores the raw message in Action Mailbox with `ActionMailbox::InboundEmail.create_and_extract_message_id!`

### Resolution and routing

`BetterTogether::InboundEmailRoutingService`:

- resolves the primary recipient address through `InboundEmailResolutionService`
- creates an encrypted `BetterTogether::InboundEmailMessage` record with sender, target, route kind, and body data
- runs `MailScreeningService` before downstream routing
- only creates downstream records when screening allows routing

Current downstream routing is intentionally narrow:

- membership-request aliases can create `BetterTogether::Joatu::MembershipRequest`
- unresolved routes are rejected and preserved as CE audit records

### Mail screening behavior

`BetterTogether::ContentSecurity::MailScreeningService` builds shared content-security payloads for:

- the inbound message body and metadata
- each attachment

It then records:

- `screening_state`
- `screening_verdict`
- `content_screening_summary`
- serialized contract records for review/audit

If the screening runner errors or returns a non-passable verdict, the message is held instead of routed.

## Active Storage release gating

The current upload slice defaults uploaded CE files to a pending/private posture until a content-security subject is releasable.

Key pieces:

- `BetterTogether::ContentSecurity::Subject` stores lifecycle and verdict state for enrolled attachments
- `AttachmentSubjectSync` keeps CE attachment records aligned with subject state
- `BlobAccessPolicy` decides whether a blob or representation may be served
- CE-generated blob URLs route through content-security proxy controllers instead of directly exposing raw storage URLs

This keeps public serving under Rails policy control and aligns with the existing CE storage-adapter direction.

## Action Text attachment controls

Action Text now respects the same release model:

- unsupported remote-style attachments are rejected during validation
- embedded blobs are enrolled into content-security subjects
- unreleased or unsupported embeds are filtered before render
- rendered embed images use CE content-security proxy paths

This keeps rich-text publication from bypassing attachment review through embedded blobs.

## Data model additions

This slice adds:

- Action Mailbox inbound email storage for CE
- `better_together_inbound_email_messages`
- `better_together_content_security_subjects`

`BetterTogether::InboundEmailMessage` encrypts:

- `subject`
- `body_plain`
- `content_screening_summary`
- `content_security_records_json`

That keeps mail content private at rest while still allowing auditable review outcomes.

## Diagram

**Diagram Files:**
- 📊 [Mermaid Source](../../diagrams/source/content_security_ingress_flow.mmd)
- 🖼️ [PNG Export](../../diagrams/exports/png/content_security_ingress_flow.png)
- 🎯 [SVG Export](../../diagrams/exports/svg/content_security_ingress_flow.svg)

## Current scope limits

This is a real enforcement slice, but it is not yet the entire final program.

- the mail path currently routes a narrow set of alias outcomes
- the orchestrator contract exists, but external scanners like ClamAV, YARA, and Rspamd still need full runtime wiring
- upload enrollment currently starts from the implemented upload and rich-text seams, not every attachment-bearing model in CE
- this slice does not add a new reviewer UI yet; it establishes the canonical CE persistence and gating path first

## Screenshots

No dedicated screenshots are included for this slice because it introduces backend ingress, routing, and serving controls rather than a new end-user or organizer-facing interface. Review evidence for this change is best represented by specs, routes, encrypted model state, and the system flow diagram above.
