# Membership Notifications TDD Acceptance Criteria

## Overview

This document defines stakeholder-focused acceptance criteria for the membership notifications feature using TDD.

---

## Feature: Membership Creation Notifications

### Implementation Plan Reference
- Plan Document: `docs/implementation/current_plans/membership_notifications_implementation_plan.md`
- Review Status: ✅ Collaborative Review Completed
- Approval Date: 2025-12-21
- Technical Approach Confirmed: Add a Noticed notifier that delivers Action Cable + email notifications when a community or platform membership is created, with a new mailer that includes a summarized permissions list and respects email preferences.

### Stakeholder Impact Analysis
- Primary Stakeholders: End users, community organizers, platform organizers
- Secondary Stakeholders: Support staff, content moderators
- Cross-Stakeholder Workflows: Memberships created by organizers or invitations triggering user notifications

---

## Phase 1: Core Membership Notifications

### 1. Membership Created Notifications

#### End User Acceptance Criteria
As an end user, I want to be notified when I gain a membership so that I understand my role and permissions.

- [ ] AC-1.1: When a community membership is created for me, I receive an in-app notification that includes the community name and my role.
- [ ] AC-1.2: When a platform membership is created for me, I receive an in-app notification that includes the platform name and my role.
- [ ] AC-1.3: When a membership is created for me, I receive an email that includes my role and a summarized list of permissions.
- [ ] AC-1.4: The email permissions summary shows a limited list and indicates when additional permissions exist.
- [ ] AC-1.5: If I have disabled email notifications, I receive only the in-app notification.

#### Community Organizer Acceptance Criteria
As a community organizer, I want members to receive clear membership notifications so that onboarding is consistent.

- [ ] AC-1.6: Community memberships created via invitation acceptance notify the new member.
- [ ] AC-1.7: Community memberships created manually by organizers notify the new member.

#### Platform Organizer Acceptance Criteria
As a platform organizer, I want platform members to be notified so that role expectations are transparent.

- [ ] AC-1.8: Platform memberships created via setup wizard or manual assignment notify the new member.
- [ ] AC-1.9: Platform membership notifications include the correct role name and joinable context.

#### Support Staff Acceptance Criteria
As a support staff member, I want notifications to include clear role summaries so that user questions are reduced.

- [ ] AC-1.10: The email content renders without missing translations across supported locales.
- [ ] AC-1.11: Notification delivery failures do not block membership creation (errors are logged).

---

## TDD Test Structure

### Test Coverage Matrix

| Acceptance Criteria | Model Tests | Request Tests | Feature Tests | Integration Tests | Mailer/Notifier Tests |
|---------------------|-------------|---------------|---------------|-------------------|-----------------------|
| AC-1.1 | ✓ | | ✓ | | ✓ |
| AC-1.2 | ✓ | | ✓ | | ✓ |
| AC-1.3 | ✓ | | ✓ | | ✓ |
| AC-1.4 | | | | | ✓ |
| AC-1.5 | ✓ | | | | ✓ |
| AC-1.6 | ✓ | ✓ | | ✓ | ✓ |
| AC-1.7 | ✓ | ✓ | | ✓ | ✓ |
| AC-1.8 | ✓ | ✓ | | ✓ | ✓ |
| AC-1.9 | | | | | ✓ |
| AC-1.10 | | | | | ✓ |
| AC-1.11 | ✓ | | | | |

### Test Implementation Plan

#### Model Tests
```ruby
# Test file: spec/models/better_together/person_community_membership_spec.rb
RSpec.describe BetterTogether::PersonCommunityMembership do
  describe 'notifications' do
    it 'delivers membership created notifications' do
      # Validates AC-1.1, AC-1.3, AC-1.6
    end
  end
end
```

```ruby
# Test file: spec/models/better_together/person_platform_membership_spec.rb
RSpec.describe BetterTogether::PersonPlatformMembership do
  describe 'notifications' do
    it 'delivers membership created notifications' do
      # Validates AC-1.2, AC-1.3, AC-1.8
    end
  end
end
```

#### Request Tests
```ruby
# Test file: spec/requests/better_together/person_community_memberships_spec.rb
RSpec.describe 'Community membership creation', :as_platform_manager do
  it 'notifies the member when an organizer creates a membership' do
    # Validates AC-1.7
  end
end
```

```ruby
# Test file: spec/requests/better_together/person_platform_memberships_spec.rb
RSpec.describe 'Platform membership creation', :as_platform_manager do
  it 'notifies the member when an organizer creates a membership' do
    # Validates AC-1.8
  end
end
```

#### Feature Tests
```ruby
# Test file: spec/features/better_together/membership_notifications_spec.rb
RSpec.feature 'Membership notifications', :as_user do
  scenario 'member sees notification for community membership' do
    # Validates AC-1.1
  end
end
```

#### Mailer/Notifier Tests
```ruby
# Test file: spec/notifiers/better_together/membership_created_notifier_spec.rb
RSpec.describe BetterTogether::MembershipCreatedNotifier do
  it 'renders the correct title/body and respects email preferences' do
    # Validates AC-1.3, AC-1.5, AC-1.9
  end
end
```

```ruby
# Test file: spec/mailers/better_together/membership_mailer_spec.rb
RSpec.describe BetterTogether::MembershipMailer do
  it 'summarizes permissions and includes role context' do
    # Validates AC-1.3, AC-1.4, AC-1.10
  end
end
```

---

## Implementation Sequence

### Red-Green-Refactor Cycle for Each Acceptance Criteria

1. RED: Write failing tests aligned to AC-1.1 through AC-1.11
2. GREEN: Implement notifier, mailer, and model hooks
3. REFACTOR: Consolidate shared logic for permission summaries and i18n usage

### Validation Checkpoints

- After each AC: related tests pass and no regressions
- After feature: run security scan with `bin/dc-run bundle exec brakeman --quiet --no-pager`

