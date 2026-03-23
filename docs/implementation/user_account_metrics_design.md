# User Account Metrics Design

## Overview

This document outlines the design for tracking user account creation and confirmation metrics in the Better Together Community Engine.

## Current Gap

The metrics system tracks page views, link clicks, downloads, shares, and search queries, but has **no tracking for user account lifecycle events**:
- User registration/account creation
- Email confirmation  
- Account types (e.g., with/without OAuth)
- Registration source (invitation vs. open)

## Design Goals

1. **Privacy-first**: Follow existing pattern - track *what* happened, not *who*
2. **Comprehensive**: Track all key account lifecycle events
3. **Actionable**: Enable platform organizers to understand user growth
4. **Consistent**: Match existing metrics system patterns

## Data Model: `BetterTogether::Metrics::UserAccountEvent`

### Fields
```ruby
- event_type:          string, null: false  # 'created', 'confirmed', 'invitation_accepted'
- occurred_at:         datetime, null: false
- locale:              string, null: false
- registration_source: string               # 'open', 'invitation', 'oauth_github', 'oauth_*'
- invitation_id:       uuid                 # if created via invitation
```

### Event Types
- `created` - New user account created (before confirmation)
- `confirmed` - User confirmed their email address
- `invitation_accepted` - User accepted invitation and created account

### Privacy Considerations
- **NO user identifiers** (no user_id, email, etc.)
- Only aggregatable metadata (types, timestamps, locale)
- Follows same pattern as existing metrics models

## Tracking Points

### 1. Account Creation
**Trigger**: After user account is created  
**Location**: `BetterTogether::User` after_create callback  
**Captured**:
- event_type: 'created'
- occurred_at: user.created_at
- locale: I18n.locale
- registration_source: 'open', 'invitation', or 'oauth_provider'
- invitation_id: invitation.id (if applicable)

### 2. Email Confirmation
**Trigger**: After user confirms email  
**Location**: Devise confirmable callback  
**Captured**:
- event_type: 'confirmed'
- occurred_at: user.confirmed_at
- locale: I18n.locale
- registration_source: same as creation event

### 3. Invitation Acceptance
**Trigger**: When invitation status changes to 'accepted'  
**Location**: `BetterTogether::Invitation` after_update callback  
**Captured**:
- event_type: 'invitation_accepted'
- occurred_at: invitation.accepted_at
- locale: I18n.locale
- invitation_id: invitation.id

## Reports

### `BetterTogether::Metrics::UserAccountReport`

**Purpose**: Aggregate user account events for analysis

**Filters**:
- `from_date`, `to_date` (date range)
- `event_type` (filter by specific event types)
- `registration_source` (filter by source type)

**Output Columns**:
- Date
- Total Events
- By Event Type (created, confirmed, invitation_accepted)
- By Registration Source (open, invitation, oauth_*)
- Confirmation Rate (confirmed/created ratio for the period)
- Locale breakdowns

**Export**: CSV with filename including filters and timestamp

## Charts

### User Growth Chart
- **Type**: Line chart
- **X-axis**: Date
- **Y-axis**: Count
- **Lines**:
  - Accounts Created
  - Accounts Confirmed
  - Invitations Accepted
- **Filters**: Date range, registration source

### Registration Source Breakdown  
- **Type**: Pie chart
- **Segments**: open, invitation, oauth_github, etc.
- **Filters**: Date range

### Confirmation Rate Trend
- **Type**: Line chart
- **X-axis**: Date
- **Y-axis**: Percentage
- **Line**: (confirmed/created) * 100
- **Filters**: Date range

## Implementation Plan

### Phase 1: Data Model & Tracking
1. Create migration for `better_together_metrics_user_account_events`
2. Create `BetterTogether::Metrics::UserAccountEvent` model
3. Add tracking job `BetterTogether::Metrics::TrackUserAccountEventJob`
4. Add callbacks to `BetterTogether::User` model
5. Add callback to `BetterTogether::Invitation` model

### Phase 2: Reports
1. Create `BetterTogether::Metrics::UserAccountReport` model
2. Create controller for report management
3. Add views for report interface
4. Add routes and navigation

### Phase 3: Charts
1. Add chart data endpoints
2. Create Stimulus controller for user metrics charts
3. Add chart views to metrics dashboard
4. Add filtering controls

### Phase 4: Testing
1. Model tests for UserAccountEvent
2. Job tests for tracking
3. Report generation tests
4. Controller tests
5. Integration/feature tests for complete flow

## Data Retention

Follow existing metrics patterns:

```ruby
# Delete events older than 180 days
BetterTogether::Metrics::UserAccountEvent.where('occurred_at < ?', 180.days.ago).in_batches.delete_all

# Purge report exports older than 90 days  
BetterTogether::Metrics::UserAccountReport.where('created_at < ?', 90.days.ago).find_each(&:destroy)
```

## Security & Privacy

- No PII stored in metrics events
- Only aggregatable data (event types, timestamps, sources)
- Respects platform privacy settings
- Follows existing metrics privacy pattern
- Data retention configurable per platform policy

## Benefits for Platform Organizers

1. **Growth Insights**: Track user acquisition over time
2. **Source Analysis**: Understand which registration methods are most effective
3. **Confirmation Rates**: Identify email delivery or UX issues
4. **Invitation Effectiveness**: Measure invitation campaign success
5. **Trend Analysis**: Spot growth patterns and anomalies
6. **Locale Distribution**: Understand geographic/language distribution

## Migration Path

This is a net-new feature - no migration of existing data needed. Once implemented, tracking begins prospectively from that point forward.

## Future Enhancements

- Track OAuth provider-specific metrics
- Track account deletion events
- Track password reset events
- Track login frequency (aggregated, not per-user)
- Integration with existing page view metrics (registration page views vs. completions)
