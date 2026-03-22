# Event Invitations & Attendance

This document provides an end-to-end, in-depth reference for event invitations and attendance (RSVP) in the Better Together Community Engine. It covers data models, controller flows, access control, invitation token handling, email and in-app notifications, RSVP life cycle, and how these pieces interact with platform privacy.

## Overview

- Event invitations allow organizers and hosts to invite existing members or external emails to a specific event.
- Invitations support secure token links for review, acceptance, or decline — including first-time registration flows.
- Acceptance automatically ensures community membership and sets RSVP to “going”, creating a calendar entry.
- Attendance (RSVP) supports two statuses: “interested” and “going”, with cancellation removing the attendance record and calendar entry.
- Invitation tokens permit access to otherwise private content for the specific invited event while preserving platform privacy.

## Core Models

- `BetterTogether::Invitation`: Polymorphic base model with `invitable`, `inviter`, optional `invitee`, `role`, `status` (string enum: pending, accepted, declined), `token` (secure), validity window, and timestamps.
- `BetterTogether::EventInvitation < Invitation`: Invitation specialization for events.
  - Status values: `pending`, `accepted`, `declined` (string enum).
  - Validates presence/inclusion of `locale` and requires one of `invitee` or `invitee_email`.
  - Prevents duplicate invitations for a given event for either the same `invitee` or the same `invitee_email` while status is in `pending` or `accepted`.
  - Methods:
    - `event`: alias to `invitable`.
    - `url_for_review`: event URL with `invitation_token` param to support review page and access.
    - `for_existing_user?` / `for_email?`: invitation mode helpers.
    - `accept!(invitee_person:)`: sets status, ensures community membership, creates/updates `EventAttendance` to `going`.
    - `decline!`: sets status to `declined`.
- `BetterTogether::EventAttendance`: RSVP record for a `person` and `event` with string enum statuses: `interested`, `going`.
  - Constraints:
    - Unique per person/event.
    - Event must be scheduled (no RSVP on drafts).
  - Side effects:
    - On `going`, creates a `CalendarEntry` in the person’s primary calendar.
    - On status change away from `going` or destroy, removes the calendar entry.

## Data Model Diagram (Invitations + Attendance)

```mermaid
%% See separate Mermaid source file for editing: docs/diagrams/source/events_invitations_schema_erd.mmd
```

**Diagram Files:**
- 📊 Mermaid Source: ../diagrams/source/events_invitations_schema_erd.mmd
- 🖼️ PNG Export: ../diagrams/exports/png/events_invitations_schema_erd.png
- 🎯 SVG Export: ../diagrams/exports/svg/events_invitations_schema_erd.svg

## Invitation Creation & Delivery

Event organizers and host representatives create invitations from the event page (Invitations panel). Two modes are supported:

- Invite existing member:
  - Provide `invitee_id` (a `BetterTogether::Person`), which auto-fills `invitee_email` and `locale` from the person record.
  - Delivery: Noticed notification to the user (`EventInvitationNotifier`) and optional email via `EventInvitationsMailer`.
- Invite by email:
  - Provide `invitee_email` and target `locale`.
  - Delivery: Email sent to the external address via `EventInvitationsMailer`.

Simple throttling prevents resending an invitation more than once within 15 minutes (`last_sent` timestamp check). Resend is supported for pending invitations.

### Controller Endpoints (Organizer/Host)

- `POST /events/:event_id/invitations` (create):
  - Authorization: `EventInvitationPolicy#create?` (organizer/host scope).
  - Parameters: `invitee_id` or `invitee_email`, optional `valid_from`, `valid_until`, `locale`, `role_id`.
  - Behavior: builds `EventInvitation`, sets `status: 'pending'`, `inviter`, and default `valid_from`.
  - Delivery: Noticed/email depending on invitation type; updates `last_sent`.

- `PUT /events/:event_id/invitations/:id/resend` (resend):
  - Authorization: same as create; respects resend throttling.

- `DELETE /events/:event_id/invitations/:id` (destroy):
  - Authorization: allowed for organizers/hosts.

- `GET /events/:event_id/invitations/available_people` (AJAX):
  - Returns up to 20 non-invited people with an email address; supports search term.
  - Uses policy scope over `Person` and joins on user/contact email.

## Public Invitation Review & Response

Public review and response routes are token-based:

- `GET /invitations/:token` → `InvitationsController#show`
- `POST /invitations/:token/accept` → `#accept`
- `POST /invitations/:token/decline` → `#decline`

Behavior:
- Finds `Invitation.pending.not_expired` by token; returns 404 if missing.
- For `accept`:
  - Requires authentication; if not signed in, stores token in session and redirects to sign-in/registration based on `invitee_email` lookup.
  - If `invitee` is bound, enforces that the logged-in person matches; otherwise, binds the invitation to the current person.
  - Calls `accept!` if available (for `EventInvitation`) or sets status to `accepted`.
  - Redirects to the invitable (event) after acceptance.
- For `decline`:
  - Calls `decline!` (or sets status) and redirects to event if available, else home.

## Access Control & Privacy with Invitation Tokens

Invitation tokens grant limited access only to the specific event to which they belong. The platform may still require login for other content.

Key elements:

- `EventsController#check_platform_privacy` augmentation:
  - For private platforms and unauthenticated users, extracts an `invitation_token` from params/session.
  - Validates token for an `EventInvitation` that matches the requested event.
  - On valid, stores token and locale in session and allows access to the event page.
  - On invalid/expired, redirects to sign-in.

- `EventPolicy#show?`:
  - Permits if event is public and scheduled, or if creator/manager/host member, or if the current person holds an invitation, or if there is a valid invitation token.

- `ApplicationPolicy::Scope` for events:
  - Includes events visible through valid `invitation_token` in the scope.

### Token Access Flow Diagram

```mermaid
%% See separate Mermaid source file for editing: docs/diagrams/source/events_access_via_invitation_token.mmd
```

**Diagram Files:**
- 📊 Mermaid Source: ../diagrams/source/events_access_via_invitation_token.mmd
- 🖼️ PNG Export: ../diagrams/exports/png/events_access_via_invitation_token.png
- 🎯 SVG Export: ../diagrams/exports/svg/events_access_via_invitation_token.svg

## Notifications

- `BetterTogether::EventInvitationNotifier` (Noticed):
  - Channels: ActionCable (in-app) and Email (`EventInvitationsMailer`).
  - Email uses parameterized mailer with `invitation` and `invitable` context.
  - Message includes localized title/body and the invitation review URL.

- `BetterTogether::EventInvitationsMailer`:
  - Sends to `invitee_email` using the invitation’s `locale`.
  - Subject includes event name with localized fallback.

## RSVP (Attendance)

The RSVP system is centered on `EventAttendance` and is managed through member routes on the `Event` resource:

- `POST /events/:id/rsvp_interested`
- `POST /events/:id/rsvp_going`
- `DELETE /events/:id/rsvp_cancel`

Constraints and behavior:
- Only available when the event is scheduled (has `starts_at`).
- Requires authentication for all RSVP actions.
- Authorization uses `EventPolicy#show?` followed by `EventAttendancePolicy` for create/update.
- On `going`, a calendar entry is created; on cancel or switching away from `going`, the entry is removed.

Existing diagrams cover the RSVP journey and reminder scheduling:
- RSVP Flow: ../diagrams/source/events_rsvp_flow.mmd
- Reminder Timeline: ../diagrams/source/events_reminders_timeline.mmd

## Organizer UI

- Invitations Panel on Event Show:
  - Tabs include Attendees and Invitations.
  - Invite by Member (`invitee_id`) or by Email (`invitee_email`).
  - View invitations table with type (member/email), status, resend/delete actions.
  - Search available people endpoint to prevent re-inviting and to filter by email presence.

## Security & Validation

- String enums: all statuses are strings for human-readable DB contents.
- Duplicate protection: event invitation uniqueness enforced for both `invitee` and `invitee_email` while status is pending/accepted.
- Privacy: invitation tokens scoped to a single event; do not grant broad platform access.
- Session token storage: invitation token and locale persisted for acceptance and consistent access; tokens expire per validity window.
- Safe dynamic resolution: no unsafe constantization of user input; controllers use allow-lists for host assignment and standard strong parameters.
- Authorization: `Pundit` policies on events, attendances, and invitations.

## Performance Considerations

- Organizer views preload invitations, invitees, and inviters to minimize N+1 queries.
- Event show preloads hosts, categories, attendances, translations, and cover image attachment.
- RSVP and invitation actions redirect back to the event to keep interaction snappy.
- Noticed notifications and email delivery run asynchronously.

## Troubleshooting

- Invitation token shows 404 on private platform:
  - Ensure the token matches the requested event and is still pending/not expired.
  - Verify session is storing `event_invitation_token` and that controller privacy check is triggered.

- Invitee required error:
  - Provide either `invitee_id` (member) or `invitee_email` (external) — one must be present.

- Duplicate invitation error:
  - An outstanding pending/accepted invitation already exists for that person or email.

- RSVP not available:
  - Event must be scheduled (`starts_at` present). Draft events do not accept RSVPs.

- Calendar entry not created:
  - Calendar entries are only created for `going` status; ensure the person has a primary calendar.

## Related Files (Code Pointers)

- Models:
  - `app/models/better_together/invitation.rb`
  - `app/models/better_together/event_invitation.rb`
  - `app/models/better_together/event_attendance.rb`

- Controllers:
  - `app/controllers/better_together/invitations_controller.rb` (unified polymorphic controller for all invitation types)
  - `app/controllers/better_together/events_controller.rb`

- Policies:
  - `app/policies/better_together/event_policy.rb`
  - `app/policies/better_together/event_invitation_policy.rb`
  - `app/policies/better_together/event_attendance_policy.rb`

- Notifications & Mailers:
  - `app/notifiers/better_together/event_invitation_notifier.rb`
  - `app/mailers/better_together/event_invitations_mailer.rb`

## Process Flow: Event Invitations

```mermaid
%% See separate Mermaid source file for editing: docs/diagrams/source/events_invitations_flow.mmd
```

**Diagram Files:**
- 📊 Mermaid Source: ../diagrams/source/events_invitations_flow.mmd
- 🖼️ PNG Export: ../diagrams/exports/png/events_invitations_flow.png
- 🎯 SVG Export: ../diagrams/exports/svg/events_invitations_flow.svg

