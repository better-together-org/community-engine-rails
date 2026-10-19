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
   - host app `ApplicationMailbox < BetterTogether::ApplicationMailbox`
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
- relies on the host app to define `ApplicationMailbox < BetterTogether::ApplicationMailbox`

### Resolution and routing

`BetterTogether::InboundEmailRoutingService`:

- resolves the primary recipient address through `InboundEmailResolutionService`
- creates an encrypted `BetterTogether::InboundEmailMessage` record with sender, target, route kind, and body data
- runs `MailScreeningService` before downstream routing
- only creates downstream records when screening allows routing

Current downstream routing is intentionally narrow:

- membership-request aliases can create `BetterTogether::Joatu::MembershipRequest`
- unresolved routes are rejected and preserved as CE audit records

### Reply by email (reply tokens)

Comment notification emails can be answered by replying. `CommentMailer#added` issues a `BetterTogether::InboundEmailReplyToken` (`InboundEmailReplyToken.issue!(recipient:, repliable:, notification_type:, platform:)`) and sets the `Reply-To` header to `reply+<token>@<inbound mail domain>`. It does this only when the platform allows inbound mail, has a primary domain hostname, and the recipient has an email address; otherwise there is no `Reply-To` and the reply goes to the `From` address.

| Column | Notes |
|---|---|
| `token` | Secure random token (`has_secure_token`) |
| `recipient` | The `Person` the email was sent to |
| `repliable` | Polymorphic target (a commentable) |
| `notification_type` | Required, for example `comment_added` |
| `platform` | Optional, checked against the receiving platform |
| `expires_at`, `consumed_at` | Tokens last 30 days (`DEFAULT_LIFETIME`) and are single use |

`InboundEmailResolutionService#reply_token_target` resolves a `reply+<token>` address only when the token is still active (not consumed, not expired), belongs to the receiving platform, and the sender address matches the recipient person; unlike `agent+` addresses it does not trust the `From` header on its own. `InboundEmailRoutingService#create_reply!` then creates a comment on the `repliable` as the recipient with the plain-text body and consumes the token, so a second reply with the same address is rejected.

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

## Review records, malware scanning and routing

Two layers record review state. **Subjects** (`better_together_content_security_subjects`, above) carry the lifecycle for enrolled attachments and embeds. **Items, scan events and findings** record the malware scanning of uploads:

| Model | Table | Role |
|---|---|---|
| `ContentSecurity::Item` | `better_together_content_security_items` | One per attached blob: `blob`, polymorphic `attachable`, `attachment_name`, `source_surface`, `lifecycle_state` and `aggregate_verdict` (`pending_scan`, `clean`, `review_required`, `quarantined`, `blocked`, `override_released`), optional `safety_case`. `releasable?` is true for `clean` and `override_released` |
| `ContentSecurity::ScanEvent` | `better_together_content_security_scan_events` | One scanner run: `status` (`started`, `completed`, `failed`, `skipped`), `plane`, `scanner_name`, version, signature, error, timestamps |
| `ContentSecurity::Finding` | `better_together_content_security_findings` | One result: `plane`, `finding_type` (`malware_signature`, `scanner_error`, ...), `rule_id`, `severity`, `confidence`, `verdict`, `evidence_summary`, linked item, scan event and safety case |

Models opt in with `ContentSecurity::ScannableAttachment` (`scans_attachment :file, surface: :uploads`; today only `Upload`). After commit, `AttachmentEnrollment.sync_attachment!` creates or updates the `Item` when scanning is enabled for that surface, resets it to `pending_scan` when the blob changed, and enqueues `ScanAttachmentJob`. Rich text uses `ContentSecurity::ActionTextRichTextControls` (included into Action Text rich text): it rejects embeds that are not Active Storage blobs and syncs a subject per embedded blob (`RichTextSubjectSync`).

`ScanAttachmentJob` calls `Scanner.scan_blob`, which streams the blob to ClamAV (`ClamAvClient`) and returns clean, infected or error:

- **clean**: the item becomes `clean` and is released.
- **infected**: a `malware_signature` finding is recorded, the item is `quarantined`, and `SafetyCaseRouter.route!` files a `Report` (category `malware_detected`, outcome `content_review`) on behalf of the uploader plus an internal note, which opens a safety case linked to the item and finding.
- **error**: with `fail_mode` `hold_until_clean` (the default) the item stays `pending_scan` with the error recorded and no case is opened, so a scanner outage does not flood the queue; with any other value the job records a `scanner_error` finding, marks the item `review_required` and routes a case. Connection errors are retried up to three times first.

Mail attachments take a separate path: `DeterministicScanRunner` runs the rule engine over the message and, when scanning is enabled for the `mail` surface, scans the raw content with ClamAV and adds `malware_signature` or `malware_scan_error` findings.

Configuration is read from `BetterTogether.content_security.malware_scanning` (initializer `better_together.content_security` in `lib/better_together/engine.rb`):

| Environment variable | Default |
|---|---|
| `BT_MALWARE_SCANNING_ENABLED` | `false` |
| `BT_MALWARE_SCANNING_ENGINE` | `clamav` (the only supported engine) |
| `BT_MALWARE_SCANNING_HOST` / `_PORT` | `127.0.0.1` / `3310` |
| `BT_MALWARE_SCANNING_TIMEOUT` | `10` seconds |
| `BT_MALWARE_SCANNING_MAX_STREAM_BYTES` | 25 MB |
| `BT_MALWARE_SCANNING_FAIL_MODE` | `hold_until_clean` |
| `BT_MALWARE_SCANNING_SURFACES` | `uploads` (comma separated; `mail` adds the mail path) |

Access is gated by `ContentSecurity::ActiveStorageGate`, included into Active Storage's blob and representation controllers, and by the proxy routes `content_security_service_blob_proxy` and `content_security_blob_representation_proxy`. The reviewer queue is the "Content security review items" section of the safety case index (`/safety/cases`); see [Safety and Federation Review Workflow](safety_and_federation_review_workflow.md) and the [operator guide](../../platform_organizers/content_security_and_malware_scanning.md).

## Diagram

**Diagram Files:**
- 📊 [Mermaid Source](../../diagrams/source/content_security_ingress_flow.mmd)
- 🖼️ [PNG Export](../../diagrams/exports/png/content_security_ingress_flow.png)
- 🎯 [SVG Export](../../diagrams/exports/svg/content_security_ingress_flow.svg)

## Current scope limits

This is a real enforcement slice, but it is not yet the entire final program.

- the mail path currently routes a narrow set of alias outcomes
- ClamAV is wired for uploads and mail attachments; YARA and Rspamd are not
- upload enrollment currently starts from the implemented upload and rich-text seams, not every attachment-bearing model in CE
- the reviewer surface is the content security section of the safety case queue; there is no dedicated content security screen

## Screenshots

No dedicated screenshots are included for this slice because it introduces backend ingress, routing, and serving controls rather than a new end-user or organizer-facing interface. Review evidence for this change is best represented by specs, routes, encrypted model state, and the system flow diagram above.
