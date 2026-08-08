# TDD Acceptance Criteria: Per-Occurrence Event Data + Recurrence-Aware Index/Calendar

## Overview

Transforms the approved plan (`feat/event-occurrences-attendance-comments-overrides`, branched off `release/0.11.0-notes` at `38f37c4fb`) into stakeholder-focused, testable acceptance criteria. Recurrence today is 100% virtual — one `Event` row + an IceCube rule, with occurrences computed on demand and never persisted. This feature adds a lightweight, lazily-created `EventOccurrence` model so a single session of a recurring series can carry its own attendance, comments, and location/time overrides — without duplicating hosting/authorization data, and without materializing a row for every occurrence up front.

## Implementation Plan Reference
- **Plan Document**: `/home/rob/.claude/plans/i-need-you-to-drifting-ladybug.md` ("Per-Occurrence Event Data (Attendance, Comments, Overrides) + Recurrence-Aware Index/Calendar")
- **Review Status**: ✅ Plan approved
- **Approval Date**: 2026-07-29
- **Technical Approach Confirmed**: Lightweight `EventOccurrence` model (not an `Event` subclass), lazily created only when a session is interacted with; `next_occurrence_at` denormalized column for index/list queries; on-demand `occurrences_between` expansion for the calendar grid; both read paths merge in `EventOccurrence` overrides when present.

## Stakeholder Impact Analysis
- **Primary Stakeholders**: End Users as **Event Attendees** (RSVP/comment per session), **Event Organizers** (hosts/creators managing a series and its exceptions)
- **Secondary Stakeholders**: **Platform Organizers** (index/calendar correctness, accessibility compliance across the whole platform), **Content Moderators** (per-session comment moderation)
- **Cross-Stakeholder Workflows**: An organizer's override of one session must be immediately visible to attendees browsing the index or calendar; an attendee's per-session RSVP must never silently apply to (or get confused with) the whole series.

## UX priorities driving this design
1. **Never show contradictory information.** A recurring event's badge, its displayed date, and its position in a sorted/filtered list must always agree — this drove the requirement that `display_event_time` and `next_occurrence_at` share one source of truth (the override-aware effective value), not two.
2. **Never punish the common case.** The overwhelming majority of occurrences are never touched by anyone — those must render exactly as fast and simply as today (no extra query, no row created just from being viewed).
3. **Never let a single-session action leak into the series**, or vice versa — RSVPing to next Tuesday must not register as "attending every week," and cancelling one session must not cancel the series.
4. **Never rely on color alone** for cancelled/rescheduled/repeats state — screen reader and low-vision users must get the same information sighted users get from a badge color.

---

## Phase 0: `EventOccurrence` model, schema, and authorization

### 0.1 Lazy per-session record creation

#### End User (Event Attendee) Acceptance Criteria
**As an event attendee, I want to interact with one specific session of a recurring event without affecting any other session, so that my RSVP/comment reflects reality (I can only make some Tuesdays, not all of them).**

- [x] **AC-0.1**: RSVPing to a specific occurrence date creates exactly one `EventOccurrence` row for that `(event, date)` pair — never one per session up front, only on first interaction.
- [x] **AC-0.2**: RSVPing to one occurrence does not create or affect an `EventOccurrence` row for any other date of the same series.
- [x] **AC-0.3**: Attempting to interact with a date that isn't a real occurrence of the series' recurrence rule is rejected with a clear error, not silently accepted.
- [x] **AC-0.4**: Viewing (not interacting with) an untouched occurrence never creates an `EventOccurrence` row — confirmed by asserting row count is unchanged after a page view.

#### Platform Organizer Acceptance Criteria
**As a platform organizer, I want per-session data to never require duplicating event hosting/ownership records, so that authorization stays correct and cheap to maintain as a series runs for years.**

- [x] **AC-0.5**: `EventOccurrencePolicy` authorizes create/update/destroy by delegating to the parent `Event`'s `event_hosts`/`creator`, reusing the exact same host-membership logic `EventPolicy` already uses (via a shared concern) — not a duplicated copy.
- [x] **AC-0.6**: No `EventHost` row is ever created for an `EventOccurrence` — confirmed by asserting `EventHost.count` is unchanged after creating/overriding several occurrences.
- [x] **AC-0.7**: A person who can manage the parent event can manage any of its occurrences; a person who cannot manage the parent event cannot override or cancel any occurrence, with no separate per-occurrence permission grant required.

---

## Phase 1: Per-session attendance and comments

### 1.1 Session-specific RSVP

#### End User (Event Attendee) Acceptance Criteria
**As an event attendee, I want to RSVP to just the sessions I can attend, so that organizers get an accurate headcount per session instead of an all-or-nothing series RSVP.**

- [x] **AC-1.1**: A person can hold one series-wide attendance (`event_occurrence_id` nil) and independently one attendance per specific session, without either overwriting the other.
- [x] **AC-1.2**: Marking "going" for one session does not change attendance status for any other session or for the series as a whole.
- [x] **AC-1.3**: Cancelling a per-session RSVP removes only that session's attendance record.
- [x] **AC-1.4**: The attendee sees a clear, immediate confirmation of *which session* their RSVP applies to (date shown, not just the series name) — preventing the confusing case of "I RSVP'd but which week was that for?"

### 1.2 Session-specific comments

#### End User (Event Attendee) Acceptance Criteria
**As an event attendee, I want to ask a question or leave a note about one specific session, so that my comment is seen by people looking at that session, not buried under unrelated comments about other weeks.**

- [x] **AC-1.5**: Comments attach to the specific `EventOccurrence`, not the parent `Event` — a comment on one session's date never appears when viewing a different session's date.
- [x] **AC-1.6**: `EventOccurrence` comments reuse the existing `Commentable` moderation/permission infrastructure already built for `Post` — no new moderation code path.

#### Content Moderator Acceptance Criteria
**As a content moderator, I want per-session event comments to appear in the same moderation queue as other comments, so that I don't need a separate workflow for recurring events.**

- [x] **AC-1.7**: A reported/flagged comment on an `EventOccurrence` surfaces through the existing content-reporting workflow identically to a comment on a `Post`.

---

## Phase 2: Organizer per-occurrence overrides

#### Event Organizer Acceptance Criteria
**As an event organizer, I want to move, retime, re-describe, or cancel one specific session without touching the recurrence rule or any other session, so that a one-off room change or cancellation doesn't require editing (or breaking) the whole series.**

- [x] **AC-2.1**: An organizer can set a location override, a time override, a description override, or toggle "cancelled" for one occurrence date, independently of every other date.
- [x] **AC-2.2**: Overriding one occurrence never modifies the base `Recurrence` rule, `exception_dates`, or any other occurrence's data.
- [x] **AC-2.3**: A non-host, non-creator person cannot override or cancel any occurrence of an event they don't manage (enforced by `EventOccurrencePolicy`, AC-0.5).
- [x] **AC-2.4**: Cancelling one occurrence still allows attendees who already RSVP'd/commented on it to see their history — cancellation does not delete the `EventOccurrence` row or its associated attendance/comments.

#### End User (Event Attendee) Acceptance Criteria
**As an event attendee, I want to immediately see when a specific session has been moved or cancelled, wherever I'm looking (calendar or event page), so that I don't show up to the wrong place or an event that isn't happening.**

- [x] **AC-2.5**: The calendar grid and the event show page both display the overridden (`effective_starts_at`/`effective_location`/`effective_description`) values for a session that has one, not the stale computed default.
- [x] **AC-2.6**: A cancelled session is visibly and unambiguously marked "Cancelled" — not merely removed from the calendar, which would look identical to "the event doesn't happen that week for unstated reasons."

---

## Phase 3: Events index recurrence-awareness

#### End User (Community Member browsing events) Acceptance Criteria
**As a community member browsing events, I want a recurring event to keep showing under "Upcoming" for as long as it keeps recurring, so that I don't miss a weekly event just because it happened to be created weeks ago.**

- [x] **AC-3.1**: A recurring event whose original `starts_at` is in the past still appears under the index's default "Upcoming" view, as long as it has a future occurrence.
- [x] **AC-3.2**: The "Past" filter correctly excludes a still-recurring event and correctly includes one whose recurrence has genuinely ended.
- [x] **AC-3.3**: Sorting by "soonest" orders recurring events by their true next occurrence date, not their original (possibly long-past) `starts_at`.
- [x] **AC-3.4**: If an organizer has overridden the very next occurrence's time (Phase 2), the index reflects that overridden time in both its sort position and its displayed date — never the un-overridden default.
- [x] **AC-3.5**: A member can filter the index to "recurring only" or "one-time only" events.

#### Platform Organizer Acceptance Criteria
**As a platform organizer, I want the events index to stay fast and paginated even with many recurring events, so that the page doesn't degrade as the platform grows.**

- [x] **AC-3.6**: The index query remains a single paginated SQL relation (Kaminari `.page`/`.per`, real `total_count`) — no in-memory array pagination fallback.
- [x] **AC-3.7**: A recurring event's `next_occurrence_at` is refreshed automatically (via scheduled job) once its previously-stored value has passed, without requiring anyone to view or edit the event.

#### End User (Event Attendee, accessibility) Acceptance Criteria
**As a screen reader or low-vision user browsing the index, I want to know an event repeats and roughly on what schedule, not just see a colored badge, so that I have the same information as a sighted user.**

- [x] **AC-3.8**: The "Repeats" badge conveys its meaning through visible text (e.g. "Repeats weekly"), never color alone.
- [x] **AC-3.9**: The badge's fuller explanation (frequency, end condition) is available via `aria-label`/tooltip, matching the existing `privacy_badge` accessibility pattern.
- [x] **AC-3.10**: The index page (card + recurring filter control) passes `be_axe_clean` at WCAG 2.1 AA.

---

## Phase 4: True calendar occurrence expansion

#### End User (Event Attendee) Acceptance Criteria
**As someone checking a calendar to plan my month, I want a weekly event to actually show up every week it happens, not just once, so that the calendar is trustworthy for planning around.**

- [x] **AC-4.1**: A weekly recurring event appears on every occurrence date within the visible month grid, not only its original creation date.
- [x] **AC-4.2**: Navigating the calendar to a future month still correctly shows the recurring event's occurrences in that month.
- [x] **AC-4.3**: Clicking any occurrence's day-cell link lands on the correct (single, canonical) event show page.
- [x] **AC-4.4**: An occurrence with an organizer override (Phase 2) shows its overridden date/location on the calendar, on the correct (possibly moved) date cell.
- [x] **AC-4.5**: A cancelled occurrence is shown with a clear "Cancelled" indicator on its calendar date, rather than silently disappearing (which would look like "no event," not "cancelled event").

---

## TDD Test Structure

### Test Coverage Matrix

| Acceptance Criteria | Model | Policy | Job | Request | Feature/Accessibility |
|---|---|---|---|---|---|
| AC-0.1 – AC-0.4 | ✓ | | | ✓ | |
| AC-0.5 – AC-0.7 | | ✓ | | ✓ | |
| AC-1.1 – AC-1.7 | ✓ | | | ✓ | |
| AC-2.1 – AC-2.6 | ✓ | ✓ | | ✓ | ✓ |
| AC-3.1 – AC-3.7 | ✓ | | ✓ | ✓ | |
| AC-3.8 – AC-3.10 | | | | | ✓ |
| AC-4.1 – AC-4.5 | | | | | ✓ |

### RED-phase pending specs (written before implementation, per this repo's TDD workflow)

- `spec/models/better_together/event_occurrence_spec.rb` — AC-0.1–0.4, AC-2.1–2.2, AC-2.4
- `spec/models/better_together/event_attendance_spec.rb` (new pending context appended) — AC-1.1–1.3
- `spec/policies/better_together/event_occurrence_policy_spec.rb` — AC-0.5–0.7, AC-2.3
- `spec/jobs/better_together/event_next_occurrence_refresh_scan_job_spec.rb` — AC-3.7
- `spec/services/better_together/events_search_filter_spec.rb` — AC-3.1–3.5
- `spec/requests/better_together/events/event_occurrence_interactions_spec.rb` — AC-1.4, AC-1.5, AC-2.1, AC-2.4–2.6
- `spec/features/events/event_occurrences_ux_spec.rb` (`type: :feature, js: true, accessibility: true`) — AC-3.8–3.10, AC-4.1–4.5

Each pending example calls the real planned API (`BetterTogether::EventOccurrence`, `event.find_or_create_occurrence_for`, `event.refresh_next_occurrence_at!`, etc.) wrapped in RSpec's `pending 'AC-X.Y: ...'` — they fail today (the code doesn't exist yet) and are expected to; the moment one passes unexpectedly, RSpec flags it so the `pending` line can be removed as that criterion is actually implemented.

---

## Out of scope (explicitly, not silently deferred)

- ICS/Google Calendar `RECURRENCE-ID` export support for overridden occurrences — both exporters currently emit RRULE-only, with no per-occurrence override representation anywhere in the codebase. Follow-up ticket.
- Federation of recurrence/occurrence data — `FederatedEventMirrorService` never mirrors `Recurrence` today. Follow-up ticket.
- `Event.ongoing` correctness for "is today's occurrence of a long-running series currently active" — a deeper, separate problem.

## Validation Checkpoints

- After each phase: all related pending specs converted from `pending` to passing; no existing spec broken; `bin/dc-run bundle exec brakeman --quiet --no-pager` clean; `bin/i18n health` clean; axe-core clean for any UI touched.
- After full feature: `bin/dc-ci` full suite green; manual walkthrough per the plan's Verification section.
