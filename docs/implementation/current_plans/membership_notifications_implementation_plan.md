# Membership Notifications Implementation Plan

## Collaborative Review Required

This implementation plan must be reviewed collaboratively before implementation begins. The plan creator should:
- Validate assumptions with stakeholders and technical leads.
- Confirm the technical approach aligns with platform values and architecture.
- Review authorization patterns to match host community role-based permissions.
- Verify UI and email UX follow cooperative and democratic principles.
- Check timeline and priorities against current platform needs.

---

## Overview

Add notifications that inform people whenever a community or platform membership is created for them. Notifications must be delivered both in-app (Action Cable via Noticed) and via email, and the email must summarize the membership role's permissions.

### Problem Statement
Memberships are created in multiple flows (invitation acceptance, registration, admin actions), but the system does not notify the recipient. People do not receive confirmation of their role or their effective permissions.

### Success Criteria
- Every community and platform membership creation sends an in-app notification and an email to the member.
- Email content includes the membership role name and a summarized list of permissions.
- Notifications respect user email preference settings.
- Tests cover membership creation flows, notifications, and email content.

---

## Stakeholder Analysis

### Primary Stakeholders
- End users: want confirmation of membership, role, and permissions.
- Community organizers: need predictable member onboarding communication.
- Platform organizers: require visibility into role and permission communication.

### Secondary Stakeholders
- Content moderators: benefit from role clarity when memberships are added.
- Support staff: reduced confusion and support requests.

### Collaborative Decision Points
- Opt-in/out behavior for membership notification emails beyond the global email preference.
- Permission summary format and maximum list size in email.
- Whether to include links to role details or permissions documentation.

---

## Implementation Priority Matrix

### Phase 1: Core Notifications (Short-Term)
Priority: High - direct requirement for membership creation.
- Create membership notification notifier and mailer.
- Trigger delivery for both community and platform memberships.
- Add i18n coverage for notification and email content.

### Phase 2: UX Enhancements (Optional)
Priority: Medium - UX polish and follow-up.
- Add settings preference for membership notifications (if desired).
- Add UI link to role permissions reference.

---

## Detailed Implementation Plan

### 1. Membership Created Notification (Timeline: Short-Term)

#### Overview
Create a Noticed notifier that delivers both in-app and email notifications for newly created community and platform memberships. The email includes a summarized permissions list derived from the role.

#### Stakeholder Acceptance Criteria
To be authored in `docs/implementation/current_plans/membership/tdd_acceptance_criteria.md` using the template at `docs/implementation/templates/tdd_acceptance_criteria_template.md` after this plan is approved.

#### Models Required/Enhanced
- `BetterTogether::PersonCommunityMembership` and `BetterTogether::PersonPlatformMembership`
  - Add `after_create_commit` hooks to trigger the notifier.
  - Ensure hooks do not raise if notifications fail (log errors).
- `BetterTogether::Role` / `BetterTogether::ResourcePermission`
  - Read-only usage for summarized permissions list.

#### Notifier
- New notifier: `BetterTogether::MembershipCreatedNotifier`
  - Deliver by Action Cable (`BetterTogether::NotificationsChannel`). The Community or Platform for the membership should be the record linked to for the notification.
  - Deliver by email via new mailer.
  - Required params: `membership` and `role` (or derive role from membership).
  - Notification title/body:
    - Role name and joinable context (community or platform).
    - Use i18n keys under `better_together.notifications.membership_created.*`.
  - Respect `recipient.notification_preferences['notify_by_email']`.

#### Mailer
- New mailer: `BetterTogether::MembershipMailer`
  - Method: `created`
  - Inputs: membership, member, role, joinable, summarized permissions.
  - Use standard mailer layout and locale/time zone handling.
  - Subject includes joinable type and name.
  - Email body includes:
    - Role name
    - Summarized permissions list (see formatting section)
    - Optional link to role details or relevant area of the site

#### Permission Summary Formatting
- Summarize by ordering permissions by `resource_type`, `position`.
- Limit list (e.g., first 5 to 8 items) with a "and N more" indicator.
- Use existing helper behavior from `BetterTogether::RolesHelper` where possible:
  - `permission_display_name`
  - `role_permission_summary`
- Provide summary in mailer via helper or a new plain Ruby service object.

#### Controllers
No controller changes required if notifications are emitted from membership models.

---

## Testing Requirements (TDD Approach)

### Acceptance Criteria Tests
To be authored after plan approval. Use stakeholder-focused feature/request specs and mailer/notifier specs.

### Model Specs
- Verify membership creation triggers notifier delivery.
- Ensure both community and platform memberships trigger notifications.
- Ensure notifications do not raise when delivery fails (log behavior).

### Notifier Specs
- Verify notification title/body content includes role and joinable context.
- Verify email delivery respects `notify_by_email` preference.

### Mailer Specs
- Subject includes joinable context.
- Body includes role name and permissions summary.
- Permissions summary truncates and includes "and N more" when applicable.

### Integration Specs
- For a membership creation via invitation acceptance or admin action, verify in-app notification presence and email delivery.

---

## I18n Requirements

- Add translation keys in all locales for:
  - Notification title/body
  - Mailer subject
  - Mailer body labels (role, permissions summary, joinable name)
- Run `bin/dc-run bin/i18n` after implementation.

---

## Risks and Mitigations

- Risk: excessive email volume if memberships are created in bulk.
  - Mitigation: keep summary concise and rely on existing email preference.
- Risk: notification failure interrupts membership creation.
  - Mitigation: deliver asynchronously and rescue/log errors.

---

## Open Questions

- Do we need a separate preference for membership emails beyond `notify_by_email`?
- Should permission summaries link to role details or a permissions reference page?
- Do we need suppression for system-created memberships during setup seeds?

