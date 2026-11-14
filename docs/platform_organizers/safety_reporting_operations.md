# Safety Reporting Operations

**Target Audience:** Platform organizers and platform-level safety reviewers  
**Document Type:** Administrator Guide  
**Last Updated:** March 2026

## Overview

The current branch includes a structured report intake flow and a linked safety-case workflow for platform managers. This guide describes the lifecycle that actually exists today.

Main files:

- `app/controllers/better_together/reports_controller.rb`
- `app/models/better_together/report.rb`
- `app/controllers/better_together/safety/cases_controller.rb`
- `app/models/better_together/safety/case.rb`
- `app/models/better_together/safety/action.rb`
- `app/models/better_together/safety/note.rb`
- `app/models/better_together/safety/agreement.rb`

## Who can operate the moderation UI

`BetterTogether::Safety::CasePolicy` currently limits case index, detail, and update access to people who can `manage_platform`.

In practice, this is a platform-level operations surface, not a community-level self-service moderation queue.

## Report intake

The current report form collects:

- category
- harm level
- requested outcome
- reason
- private details
- consent to contact
- consent to restorative process
- retaliation risk

Allowed reportable classes currently include:

- people
- posts
- events
- messages
- Joatu offers, requests, and agreements

`ReportsController` resolves reportable targets through `SafeClassResolver` and returns `404` for invalid or missing targets before the normal authorization flow completes.

## Automatic case creation

Every saved report automatically creates a linked `Safety::Case` through `after_create_commit :ensure_safety_case!` unless one already exists.

The case copies the core intake fields from the report so reviewers can work from a normalized moderation record.

## Default lane assignment

`Safety::Case#set_default_lane` assigns a lane on create:

- `immediate_safety` for urgent harm or retaliation risk
- `administrative` for `spam_or_scam`, `fraud`, `impersonation`, or `misinformation`
- `restorative` for everything else

Treat this as the branch-supported default triage automation. Reviewers can still change the lane later from the case management form.

## Status lifecycle

Current statuses:

- `submitted`
- `triaged`
- `needs_reporter_followup`
- `restorative_in_progress`
- `protective_action_in_effect`
- `resolved`
- `closed_no_action`

When a case is updated to `resolved` and `resolved_at` is blank, `CasesController#update` stamps the resolution time.

## Reporter-visible lifecycle

Reporter-facing pages intentionally show less detail than the moderator workflow.

`reporter_visible_status` currently maps:

- `submitted` -> `under_review`
- `triaged` -> `under_review`
- all later statuses -> their actual status values

The report detail page may also show a `closure_summary` when reviewers add one.

## Moderator workflow in the current UI

### Case list

`/safety_cases` supports filtering by:

- status
- lane
- harm level

The list view shows the category, lane, truncated report reason, current status, and created timestamp.

### Case detail

The case detail page gives reviewers four operational areas:

1. intake details from the original report
2. actions
3. notes
4. agreements and case management

## Actions

Current action types include:

- `content_hidden`
- `content_removed`
- `contact_restriction`
- `messaging_restriction`
- `event_restriction`
- `temporary_suspension`
- `restorative_referral`
- `watch_flag`

Current action statuses:

- `active`
- `completed`
- `cancelled`

Important constraint: active actions require `review_at`.

The action form also records four BTS values checks and freeform review notes:

- love/inclusivity
- solidarity
- accountability
- care

## Notes

Notes can be saved as:

- `internal_only`
- `participant_visible`

Use participant-visible notes carefully. Reporter-facing status pages are still limited, so do not assume every internal moderation detail is exposed back to the person who filed the report.

## Agreements

Agreements support a restorative path with:

- summary
- commitments
- harmed-party consent
- responsible-party consent
- status updates
- optional completion timestamps

Agreement statuses:

- `proposed`
- `active`
- `completed`
- `breached`
- `withdrawn`

## Case management fields exposed today

The current case-management form lets reviewers update:

- `status`
- `lane`
- `closure_type`
- `closure_summary`
- `review_at`

Even though `assigned_reviewer_id` is permitted in the controller, the current branch does not expose an assignee selector in the case detail UI. Plan staffing workflows accordingly.

## Practical release checks

Before calling the workflow ready for release, verify that:

- a new report creates a linked safety case
- urgent or retaliation-risk reports land in `immediate_safety`
- administrative categories route to the administrative lane by default
- reporter history pages show the expected reduced status vocabulary
- closure summaries appear only when added to the safety case

## Related docs

- [Reporting Harm and Safety Concerns](../end_users/reporting_harm_and_safety_concerns.md)
- [After You Report](../end_users/after_you_report.md)
- [Safety report lifecycle flow](../diagrams/source/safety_report_lifecycle_flow.mmd)
- [0.11.0 Release Overview](../releases/0.11.0.md)
