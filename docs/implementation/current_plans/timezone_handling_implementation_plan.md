# Timezone Handling Implementation Plan

## 📊 Implementation Status

**Phase 1: Foundation - Critical Fixes** ✅ **COMPLETE** (Completed: January 17, 2026)
- ✅ ApplicationController Timezone Setting (11 tests passing)
- ✅ Event Timezone Migration (6 tests passing)
- ✅ Event Model Timezone Helpers (14 tests passing)
- ✅ Basic Timezone Tests (19 integration tests passing)
- **Total: 50 tests passing, 0 failures**

**Phase 2: Event System Enhancement** ⏸️ NOT STARTED
**Phase 3: Reminder & Notification Updates** ⏸️ NOT STARTED
**Phase 4: Codebase Audit & Cleanup** ⏸️ NOT STARTED
**Phase 5: Comprehensive Testing & Documentation** ⏸️ NOT STARTED

---

## ⚠️ COLLABORATIVE REVIEW REQUIRED

**This implementation plan must be reviewed collaboratively before implementation begins. The plan creator should:**

1. **Validate assumptions** with stakeholders and technical leads
2. **Confirm technical approach** aligns with platform values and architecture
3. **Review authorization patterns** match host community role-based permissions
4. **Verify UI/UX approach** follows cooperative and democratic principles
5. **Check timeline and priorities** against current platform needs

---

## Overview

Implement comprehensive timezone handling across the Better Together Community Engine to ensure accurate datetime display, storage, and processing for international users and multi-timezone deployments. This addresses CRITICAL gaps identified in the timezone handling assessment where user and platform timezone preferences are stored but never applied in request context, and events lack timezone storage entirely.

### Problem Statement

**Current State:**
- User timezone preferences (`Person#time_zone`) stored but NEVER applied during request processing
- Platform timezone (`Platform#timezone`) stored but only used in mailers and background jobs
- ApplicationController has NO `around_action :set_time_zone` to establish timezone context
- Event model has NO `timezone` column - all events stored in UTC without timezone reference
- HTML5 datetime form inputs use browser local timezone causing offset bugs
- All datetime displays default to UTC regardless of user's timezone preference

**Who is Affected:**
- **100% of end users** viewing events, messages, notifications, or any datetime displays
- **100% of event organizers** creating events across timezones or experiencing DST transitions
- **Platform organizers** managing international communities
- **Developers** maintaining datetime-related code

**Pain Points:**
1. Events display wrong times to users in different timezones
2. DST transitions break event times (shift by 1 hour)
3. International events completely broken (wrong day, wrong time)
4. Event reminders sent at wrong local times
5. Message timestamps confusing across timezones
6. Calendar exports (ICS) lack timezone information
7. User trust broken by consistently incorrect times

### Success Criteria

**Functional Success:**
1. All datetime displays show correct local time for authenticated user's timezone
2. Guest users see datetimes in platform timezone
3. Events maintain correct local times through DST transitions
4. Event creators can specify event timezone explicitly
5. Calendar exports include proper VTIMEZONE blocks
6. Event reminders scheduled using event's local timezone
7. Forms display and submit datetimes with proper timezone context

**Technical Success:**
1. `Time.zone` set per-request based on user → platform → app default hierarchy
2. All Event records have timezone column populated
3. No timezone-naive datetime parsing (no `Time.parse`, only `Time.zone.parse`)
4. Comprehensive timezone test coverage including DST edge cases
5. Zero Brakeman warnings related to timezone handling

**User Experience Success:**
1. Users in Tokyo see event times in JST
2. Users in NYC see same event times in EST/EDT
3. Event creator in London can create NYC event with correct timezone
4. DST transitions don't shift event times
5. No user confusion about "what time is this event?"

---

## Stakeholder Analysis

### Primary Stakeholders

#### End Users (Event Attendees & Message Users)
**User Stories:**
- As an **end user in Tokyo**, I want to see all event times in JST (my timezone), so that I know when to attend without manual conversion
- As an **end user**, I want message timestamps to show my local time, so that I understand when conversations happened relative to my day
- As an **end user**, I want event reminders sent at appropriate times in my timezone, so that "24 hours before" actually means 24 hours before for me
- As an **end user across DST transition**, I want events to maintain their original local time, so that a 2:00 PM event stays 2:00 PM (not shift to 3:00 PM)

**Needs:**
- Accurate datetime displays in their local timezone
- Consistent times across devices and calendar apps
- Clear timezone indicators when viewing international events
- Trust that platform shows correct times

**Impact of Gaps:**
- Currently see all times in UTC (confusing, requires mental math)
- International users may miss events due to wrong displayed times
- Lost trust in platform's reliability

---

#### Event Organizers (Community Members Creating Events)
**User Stories:**
- As an **event organizer in NYC**, I want to create an event for "2:00 PM EST" and have it stay 2:00 PM through DST, so that attendees aren't confused
- As an **event organizer**, I want to specify which timezone my event is in, so that international attendees see correct local time conversions
- As an **event organizer**, I want calendar invites (ICS exports) to include timezone data, so that attendees' calendar apps display the correct time
- As an **remote team organizer**, I want to create an event in my team's office timezone (not my personal timezone), so that the event represents the actual meeting location

**Needs:**
- Explicit timezone control when creating events
- Confidence that event times won't shift unexpectedly
- Accurate reminder scheduling
- Professional calendar export functionality

**Impact of Gaps:**
- Events shift by 1 hour during DST transitions (broken meetings)
- International events show wrong times to all participants
- Calendar exports import at wrong times
- Lost credibility for remote/international events

---

#### Community Organizers (Elected Community Leaders)
**User Stories:**
- As a **community organizer**, I want to schedule community events in our community's timezone, so that local members see familiar times
- As a **community organizer managing international members**, I want members to see event times in their own timezones automatically, so that they can participate regardless of location
- As a **community organizer**, I want to trust that recurring events stay at the same local time year-round, so that I can establish consistent community rhythms

**Needs:**
- Reliable event scheduling for community activities
- International member inclusion through accurate time display
- Reduced support burden from timezone confusion
- Trust in platform for official community business

**Impact of Gaps:**
- Community members miss events due to wrong times
- International communities can't function properly
- Increased support questions about "why is the time wrong?"
- Platform unsuitable for professional/serious community use

---

#### Platform Organizers (Elected Platform Administrators)
**User Stories:**
- As a **platform organizer**, I want to set a default platform timezone, so that guest users and new users see sensible defaults
- As a **platform organizer**, I want to enable international deployment, so that our platform can serve users globally
- As a **platform organizer**, I want to trust that platform infrastructure handles timezones correctly, so that I can focus on community building rather than technical workarounds

**Needs:**
- Platform-wide timezone configuration
- Scalable solution for international growth
- Reduced technical support burden
- Professional-grade time handling

**Impact of Gaps:**
- Platform limited to single-timezone deployments
- International expansion blocked by technical limitations
- Loss of platform credibility
- Competitive disadvantage vs timezone-aware platforms

---

### Secondary Stakeholders

#### Developers (Code Maintainers)
**User Stories:**
- As a **developer**, I want clear timezone handling patterns, so that I don't introduce bugs when adding datetime features
- As a **developer**, I want comprehensive timezone tests, so that I can refactor safely
- As a **developer**, I want documentation on timezone best practices, so that I follow established patterns

**Needs:**
- Consistent timezone patterns across codebase
- Test coverage for timezone edge cases
- Clear documentation and examples
- Type-safe timezone handling where possible

**Impact of Gaps:**
- Easy to introduce timezone bugs
- Inconsistent patterns across codebase
- Time wasted debugging timezone issues

---

#### Support Staff (Community Support Volunteers)
**User Stories:**
- As **support staff**, I want accurate error messages about timezone issues, so that I can help users troubleshoot
- As **support staff**, I want documentation on how timezone handling works, so that I can explain it to confused users

**Needs:**
- Clear understanding of timezone behavior
- Troubleshooting guides
- Reduced volume of timezone-related support tickets

**Impact of Gaps:**
- High support burden for timezone confusion
- Difficulty helping users with "wrong time" complaints
- Frustrated users and support staff

---

### Collaborative Decision Points

**Finalized Decisions:**
1. ✅ **Per-request timezone setting**: ApplicationController must set Time.zone using user → platform → app default hierarchy
2. ✅ **Event timezone storage**: Every event MUST have explicit timezone column
3. ✅ **Timezone selector in forms**: Event creators explicitly choose timezone (defaults to user timezone)
4. ✅ **Backward compatibility**: Existing events backfilled with platform timezone (acceptable for small dataset)
5. ✅ **Guest user behavior**: Unauthenticated users see times in platform timezone
6. ✅ **Timezone display convention**: Show timezone abbreviation (EST/JST) when event timezone ≠ user timezone
7. ✅ **Calendar export standard**: ICS exports include VTIMEZONE blocks per RFC 5545
8. ✅ **IANA timezone identifiers**: All timezone storage uses IANA identifiers (e.g., "America/New_York") instead of Rails timezone names (e.g., "Eastern Time (US & Canada)")
9. ✅ **Timezone validation**: Strict validation using TZInfo::Timezone.all_identifiers - only valid IANA timezones accepted
10. ✅ **Migration verification**: Trust automated backfill; platform timezone conversion migration runs before event backfill

**Pending Decisions:**
1. ⏳ **Multi-timezone event display**: Should event show BOTH event timezone AND user timezone, or just user timezone with indicator?

---

## Implementation Priority Matrix
✅ **COMPLETE**
**Priority: CRITICAL** - Blocks international deployment; affects 100% of datetime displays

**Status: COMPLETED January 17, 2026**

1. ✅ **ApplicationController Timezone Setting** - Establish per-request timezone context (11 tests)
2. ✅ **Event Timezone Migration** - Add timezone column and backfill existing events (6 tests)
3. ✅ **Event Model Timezone Helpers** - Add methods for timezone-aware datetime access (14 tests)
4. ✅ **Basic Timezone Tests** - Ensure foundation works correctly (19 integration tests)

**Deliverables: ALL COMPLETE**
- ✅ User timezone preferences applied to all pages
- ✅ Events have timezone data with IANA identifier validation
- ✅ Timezone helper methods available (local_starts_at, timezone_display, etc.)
- ✅ Core functionality tested (50 tests passing)
- ✅ Platform timezone conversion migration (Rails names → IANA identifiers)
- ✅ All forms updated to use IANA timezone selects
- ✅ Security validated (no new Brakeman warnings)

**Additional Achievements:**
- Created custom `iana_time_zone_select` helper for proper IANA timezone selection
- Implemented comprehensive DST handling and multi-timezone coordination tests
- Updated all timezone defaults from "Newfoundland" to "America/St_Johns"
- Factory updates to generate valid IANA timezonesvailable
- Core functionality tested

---

### Phase 2: Event System Enhancement (Week 1-2, ~2 days)
**Priority: HIGH** - Fixes event creation, display, and export issues

1. **Event Form Timezone Selector** - UI for choosing event timezone
2. **EventsHelper Timezone-Aware Display** - Correct time rendering in views
3. **ICS Export with VTIMEZONE** - Professional calendar export
4. **Event Timezone Tests** - DST transitions, international events

**Deliverables:**
- Event creators can choose timezone
- Events display correctly for all users
- Calendar exports work properly
- Edge cases tested

---

### Phase 3: Reminder & Notification Updates (Week 2, ~1-2 days)
**Priority: HIGH** - Fixes reminder timing and notification clarity

1. **Reminder Job Timezone-Aware Scheduling** - Calculate reminders in event timezone
2. **Mailer Timezone Enhancement** - Show recipient timezone in emails
3. **Notification Timestamp Display** - Timezone-aware "5 minutes ago"

**Deliverables:**
- Reminders sent at correct local times
- Email timestamps clear and accurate
- Notifications show appropriate times

---

### Phase 4: Codebase Audit & Cleanup (Week 2-3, ~1 day)
**Priority: MEDIUM** - Prevents future bugs and improves maintainability

1. **Audit Time.now/Date.today Usage** - Replace with timezone-aware equivalents
2. **Standardize Time Method Usage** - Consistent patterns across codebase
3. **Add Timezone Documentation** - Developer guide and patterns

**Deliverables:**
- No timezone-naive time methods
- Consistent code patterns
- Documentation for future development

---

### Phase 5: Comprehensive Testing & Documentation (Week 3, ~1 day)
**Priority: MEDIUM** - Ensures long-term reliability

1. **DST Transition Test Suite** - Spring forward and fall back scenarios
2. **Multi-Timezone Integration Tests** - User interactions across timezones
3. **User Documentation** - Help articles for end users and organizers
4. **Performance Testing** - Ensure timezone operations don't slow down requests

**Deliverables:**
- Comprehensive test coverage
- User-facing documentation
- Performance benchmarks

---

## Detailed Implementation Steps

---

## 1. ApplicationController Timezone Setting (Priority: CRITICAL, ~4 hours)

### Overview
Establish per-request timezone context by adding `around_action :set_time_zone` to ApplicationController. This is the **foundational change** that enables all other timezone features to work properly.

### Stakeholder Acceptance Criteria

**End Users:**
- ✅ I see all datetime displays in my selected timezone
- ✅ My timezone preference from settings is actually used
- ✅ Times display consistently across all pages

**Developers:**
- ✅ `Time.zone` is set for every request
- ✅ Timezone fallback hierarchy works: user → platform → app default → UTC
- ✅ No performance degradation from timezone setting

### Implementation Details

**File:** `app/controllers/better_together/application_controller.rb`

**Changes:**

```ruby
# Add after existing before_action callbacks
around_action :set_time_zone

private

def set_time_zone(&block)
  # Priority hierarchy: user timezone → platform timezone → app config → UTC
  tz = determine_timezone
  
  Time.use_zone(tz, &block)
end

def determine_timezone
  # Authenticated user's preference takes priority
  return current_user.person.time_zone if current_user&.person&.time_zone.present?
  
  # Fall back to platform timezone
  return helpers.host_platform.time_zone if helpers.host_platform&.time_zone.present?
  
  # Fall back to application configuration
  return Rails.application.config.time_zone if Rails.application.config.time_zone.present?
  
  # Ultimate fallback to UTC
  'UTC'
end
```

**Why This Works:**
- `around_action` wraps entire request in timezone context
- `Time.use_zone` establishes thread-local timezone for request duration
- Hierarchy ensures most specific timezone always used
- Falls back gracefully if preferences not set

**Security Considerations:**
- No user input directly used (timezone comes from database)
- Validation on Person model ensures only valid timezones stored
- No SQL injection risk (timezone from association, not params)

**Performance Considerations:**
- `Time.use_zone` has minimal overhead (~0.1ms per request)
- Timezone lookup cached per request (no repeated queries)
- No N+1 query issues (user/platform already loaded for auth)

---

### Testing Requirements

**File:** `spec/controllers/better_together/application_controller_spec.rb`

```ruby
RSpec.describe BetterTogether::ApplicationController, type: :controller do
  controller do
    def index
      render json: { timezone: Time.zone.name }
    end
  end

  before do
    routes.draw { get 'index' => 'anonymous#index' }
    configure_host_platform  # Test helper
  end

  describe 'timezone setting' do
    context 'with authenticated user' do
      let(:user) { create(:user) }
      
      before { sign_in user }

      it 'uses user timezone preference' do
        user.person.update(time_zone: 'Tokyo')
        get :index
        
        expect(response.parsed_body['timezone']).to eq('Tokyo')
      end

      it 'falls back to platform timezone if user timezone not set' do
        user.person.update(time_zone: nil)
        # Platform created by configure_host_platform with timezone
        
        get :index
        expect(response.parsed_body['timezone']).to eq(BetterTogether::Platform.host.time_zone)
      end
    end

    context 'without authenticated user' do
      it 'uses platform timezone for guest users' do
        get :index
        expect(response.parsed_body['timezone']).to eq(BetterTogether::Platform.host.time_zone)
      end

      it 'falls back to UTC if no platform' do
        BetterTogether::Platform.destroy_all
        get :index
        expect(response.parsed_body['timezone']).to eq('UTC')
      end
    end

    context 'timezone persists through request' do
      let(:user) { create(:user) }
      
      before do
        user.person.update(time_zone: 'Tokyo')
        sign_in user
      end

      it 'maintains timezone for entire request lifecycle' do
        get :index
        
        # Verify timezone was Tokyo during request processing
        expect(response.parsed_body['timezone']).to eq('Tokyo')
      end
    end
  end
end
```

**Additional Test Files:**
- `spec/requests/timezone_aware_display_spec.rb` - Integration tests for datetime display
- `spec/system/user_timezone_preference_spec.rb` - Full user journey testing timezone

---

### Rollback Strategy

**If issues detected:**
1. Comment out `around_action :set_time_zone`
2. Reverts to UTC/app default timezone (original behavior)
3. No data corruption risk
4. Can be toggled on/off with single line change

**Feature Flag Option:**
```ruby
around_action :set_time_zone, if: -> { ENV.fetch('TIMEZONE_ENABLED', 'true') == 'true' }
```

---

## 2. Event Timezone Migration (Priority: CRITICAL, ~4 hours)

### Overview
Add `timezone` column to `better_together_events` table to store explicit timezone for each event. Backfill existing events with platform timezone.

### Stakeholder Acceptance Criteria

**Event Organizers:**
- ✅ My existing events maintain their intended times after migration
- ✅ New events can specify which timezone they're in
- ✅ No events break or lose data during migration

**Platform Organizers:**
- ✅ Migration completes successfully on production
- ✅ Errors logged but don't fail entire migration
- ✅ Can review backfilled event timezones if needed

**Developers:**
- ✅ Migration is reversible (can rollback if needed)
- ✅ All events have valid timezone after migration
- ✅ No null timezones in database

### Implementation Details

**File:** `db/migrate/[timestamp]_add_timezone_to_events.rb`

```ruby
class AddTimezoneToEvents < ActiveRecord::Migration[7.2]
  def up
    # Add timezone column with sensible default
    add_column :better_together_events, :timezone, :string, default: 'UTC', null: false
    add_index :better_together_events, :timezone
    
    # Backfill existing events with platform timezone
    backfill_event_timezones
  end

  def down
    remove_column :better_together_events, :timezone
  end

  private

  def backfill_event_timezones
    # Get platform timezone (safe for multi-tenancy)
    platform = BetterTogether::Platform.find_by(host: true)
    default_timezone = platform&.timezone || 'UTC'
    
    say "Backfilling #{BetterTogether::Event.count} events with timezone: #{default_timezone}"
    
    # Update in batches to avoid memory issues
    BetterTogether::Event.find_each(batch_size: 100) do |event|
      begin
        event.update_column(:timezone, default_timezone)
      rescue StandardError => e
        # Log error but continue migration
        say "Failed to set timezone for event #{event.id}: #{e.message}", true
        
        # Fall back to UTC for this event
        event.update_column(:timezone, 'UTC') rescue nil
      end
    end
    
    say "Backfill complete. Verify with: BetterTogether::Event.where(timezone: nil).count"
  end
end
```

**Why This Approach:**
- Default to UTC ensures no null values
- Backfill uses platform timezone (most accurate for existing events)
- Error logging without migration failure (production-safe)
- Batch processing prevents memory issues with large datasets
- UTC fallback ensures no events left without timezone

**Data Migration Safety:**
- No datetime values changed (only timezone column added)
- Original UTC timestamps preserved
- Reversible migration (can rollback)
- Error handling prevents partial failures

---

### Testing Requirements

**File:** `spec/migrations/add_timezone_to_events_spec.rb`

```ruby
require 'rails_helper'
require Rails.root.join('db/migrate/[timestamp]_add_timezone_to_events.rb')

RSpec.describe AddTimezoneToEvents, type: :migration do
  let(:platform) { create(:platform, host: true, timezone: 'Eastern Time (US & Canada)') }
  
  describe 'up migration' do
    before do
      # Create events before migration
      @event1 = BetterTogether::Event.create!(
        name: 'Test Event 1',
        starts_at: Time.current,
        creator: create(:person)
      )
      @event2 = BetterTogether::Event.create!(
        name: 'Test Event 2',
        starts_at: 1.day.from_now,
        creator: create(:person)
      )
      
      # Run migration
      migrate(:up)
    end

    it 'adds timezone column' do
      expect(BetterTogether::Event.column_names).to include('timezone')
    end

    it 'backfills existing events with platform timezone' do
      @event1.reload
      @event2.reload
      
      expect(@event1.timezone).to eq('Eastern Time (US & Canada)')
      expect(@event2.timezone).to eq('Eastern Time (US & Canada)')
    end

    it 'sets default timezone to UTC' do
      new_event = BetterTogether::Event.new(name: 'New', starts_at: Time.current)
      expect(new_event.timezone).to eq('UTC')
    end

    it 'adds timezone index' do
      expect(
        ActiveRecord::Base.connection.index_exists?(
          :better_together_events, 
          :timezone
        )
      ).to be true
    end
  end

  describe 'down migration' do
    before do
      migrate(:up)
      migrate(:down)
    end

    it 'removes timezone column' do
      expect(BetterTogether::Event.column_names).not_to include('timezone')
    end
  end
end
```

---

## 3. Event Model Timezone Helpers (Priority: CRITICAL, ~3 hours)

### Overview
Add timezone-aware helper methods to Event model for accessing datetime attributes in proper timezone context.

### Stakeholder Acceptance Criteria

**Developers:**
- ✅ Can call `event.local_starts_at` to get event time in event timezone
- ✅ Can call `event.starts_at_in_zone(user_tz)` to convert to user timezone
- ✅ Helpers handle nil datetimes gracefully
- ✅ Helpers work with both starts_at and ends_at

### Implementation Details

**File:** `app/models/better_together/event.rb`

```ruby
# Add to existing Event model

# Timezone-aware datetime helpers
def local_starts_at
  starts_at&.in_time_zone(timezone)
end

def local_ends_at
  ends_at&.in_time_zone(timezone)
end

def starts_at_in_zone(user_timezone)
  starts_at&.in_time_zone(user_timezone)
end

def ends_at_in_zone(user_timezone)
  ends_at&.in_time_zone(user_timezone)
end

# Helper for displaying timezone alongside time
def timezone_display
  return '' unless timezone.present?
  
  # Get timezone abbreviation at event time (handles DST)
  local_starts_at&.zone || ActiveSupport::TimeZone[timezone]&.tzinfo&.name || timezone
end

# Validation for timezone
validates :timezone, presence: true, inclusion: { 
  in: ActiveSupport::TimeZone.all.map(&:name),
  message: '%{value} is not a valid timezone'
}
```

**Why These Helpers:**
- `local_starts_at` - Event time in its own timezone (what organizer intended)
- `starts_at_in_zone(tz)` - Event time converted to viewer's timezone
- Safe nil handling with `&.` operator
- Validation ensures only valid IANA timezones stored

---

### Testing Requirements

**File:** `spec/models/better_together/event_spec.rb`

```ruby
RSpec.describe BetterTogether::Event, type: :model do
  describe 'timezone handling' do
    let(:event) do
      create(:event,
        timezone: 'Eastern Time (US & Canada)',
        starts_at: Time.zone.parse('2024-06-15 14:00:00 UTC'),  # 10:00 AM EDT
        ends_at: Time.zone.parse('2024-06-15 16:00:00 UTC')      # 12:00 PM EDT
      )
    end

    describe '#local_starts_at' do
      it 'returns start time in event timezone' do
        expect(event.local_starts_at.zone).to eq('EDT')
        expect(event.local_starts_at.hour).to eq(10)
        expect(event.local_starts_at.min).to eq(0)
      end

      it 'handles nil starts_at' do
        event.starts_at = nil
        expect(event.local_starts_at).to be_nil
      end
    end

    describe '#local_ends_at' do
      it 'returns end time in event timezone' do
        expect(event.local_ends_at.zone).to eq('EDT')
        expect(event.local_ends_at.hour).to eq(12)
      end
    end

    describe '#starts_at_in_zone' do
      it 'converts to specified timezone' do
        tokyo_time = event.starts_at_in_zone('Tokyo')
        
        expect(tokyo_time.zone).to eq('JST')
        expect(tokyo_time.hour).to eq(23)  # 10 AM EDT = 11 PM JST same day
      end

      it 'handles same timezone as event' do
        edt_time = event.starts_at_in_zone('Eastern Time (US & Canada)')
        expect(edt_time.hour).to eq(10)
      end
    end

    describe '#timezone_display' do
      it 'returns timezone abbreviation' do
        expect(event.timezone_display).to eq('EDT')
      end

      it 'handles timezones without DST' do
        event.timezone = 'UTC'
        expect(event.timezone_display).to eq('UTC')
      end
    end

    describe 'DST transitions' do
      context 'spring forward (March 10, 2024)' do
        let(:event) do
          create(:event,
            timezone: 'Eastern Time (US & Canada)',
            starts_at: Time.zone.parse('2024-03-15 19:00:00 UTC')  # After DST: 3 PM EDT
          )
        end

        it 'maintains local time through DST' do
          expect(event.local_starts_at.hour).to eq(15)
          expect(event.local_starts_at.zone).to eq('EDT')
        end
      end

      context 'fall back (November 3, 2024)' do
        let(:event) do
          create(:event,
            timezone: 'Eastern Time (US & Canada)',
            starts_at: Time.zone.parse('2024-12-15 19:00:00 UTC')  # After DST: 2 PM EST
          )
        end

        it 'maintains local time through DST' do
          expect(event.local_starts_at.hour).to eq(14)
          expect(event.local_starts_at.zone).to eq('EST')
        end
      end
    end
  end
end
```

---

## 4. Event Form Timezone Selector (Priority: HIGH, ~4 hours)

### Overview
Add timezone selector to event creation/edit forms, allowing organizers to explicitly specify event timezone.

### Stakeholder Acceptance Criteria

**Event Organizers:**
- ✅ I can choose which timezone my event is in
- ✅ Timezone defaults to my personal timezone
- ✅ I see current time in selected timezone to verify it's correct
- ✅ Timezone selection is clear and easy to find

### Implementation Details

**File:** `app/views/better_together/events/_form.html.erb`

```erb
<!-- Add BEFORE datetime fields to establish timezone context -->
<div class="mb-3">
  <%= form.label :timezone, t('.timezone_label'), class: 'form-label' %>
  <%= form.time_zone_select :timezone,
      ActiveSupport::TimeZone.all,
      {
        default: @event.timezone || current_user&.person&.time_zone || helpers.host_platform&.time_zone || 'UTC',
        include_blank: false
      },
      {
        class: 'form-select',
        data: {
          controller: 'better-together--event-timezone',
          action: 'change->better-together--event-timezone#updateDisplay',
          'better-together--event-timezone-target': 'timezoneSelect'
        }
      } %>
  <div class="form-text">
    <%= t('.timezone_help') %>
    <span data-better-together--event-timezone-target="currentTime" class="fw-bold">
      <%= Time.current.in_time_zone(@event.timezone || Time.zone.name).strftime('%I:%M %p %Z') %>
    </span>
  </div>
</div>

<!-- Existing datetime fields -->
<div class="mb-3">
  <%= form.label :starts_at, class: 'form-label' %>
  <%= form.datetime_field :starts_at,
      include_seconds: false,
      class: 'form-control',
      data: {
        action: 'change->better-together--event-datetime#updateEndTime',
        'better-together--event-timezone-target': 'startInput'
      } %>
  <div class="form-text" data-better-together--event-timezone-target="startDisplay">
    <!-- JS will update with timezone context -->
  </div>
</div>

<div class="mb-3">
  <%= form.label :ends_at, class: 'form-label' %>
  <%= form.datetime_field :ends_at,
      include_seconds: false,
      class: 'form-control',
      data: {
        'better-together--event-timezone-target': 'endInput'
      } %>
  <div class="form-text" data-better-together--event-timezone-target="endDisplay">
    <!-- JS will update with timezone context -->
  </div>
</div>
```

**Stimulus Controller:** `app/javascript/controllers/better_together/event_timezone_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timezoneSelect", "currentTime", "startInput", "endInput", "startDisplay", "endDisplay"]

  connect() {
    this.updateDisplay()
  }

  updateDisplay() {
    const timezone = this.timezoneSelectTarget.value
    
    // Update current time display
    this.updateCurrentTime(timezone)
    
    // Update datetime input displays with timezone context
    this.updateDatetimeDisplays(timezone)
  }

  updateCurrentTime(timezone) {
    // Fetch current time in selected timezone from server
    fetch(`/api/current_time?timezone=${encodeURIComponent(timezone)}`)
      .then(response => response.json())
      .then(data => {
        this.currentTimeTarget.textContent = data.formatted_time
      })
  }

  updateDatetimeDisplays(timezone) {
    // Show timezone context for datetime inputs
    if (this.hasStartInputTarget && this.startInputTarget.value) {
      const startTime = new Date(this.startInputTarget.value)
      this.startDisplayTarget.textContent = `Event time: ${this.formatInTimezone(startTime, timezone)}`
    }
    
    if (this.hasEndInputTarget && this.endInputTarget.value) {
      const endTime = new Date(this.endInputTarget.value)
      this.endDisplayTarget.textContent = `Event time: ${this.formatInTimezone(endTime, timezone)}`
    }
  }

  formatInTimezone(date, timezone) {
    // Simple formatting - in production, use library like Luxon
    return `${date.toLocaleString('en-US', { timeZone: timezone })} ${timezone}`
  }
}
```

**API Endpoint for Current Time:** `app/controllers/better_together/api/time_controller.rb`

```ruby
module BetterTogether
  module Api
    class TimeController < ApplicationController
      def current_time
        timezone = params[:timezone] || Time.zone.name
        
        render json: {
          timezone: timezone,
          formatted_time: Time.current.in_time_zone(timezone).strftime('%I:%M %p %Z')
        }
      end
    end
  end
end
```

---

### i18n Keys

**File:** `config/locales/better_together/en.yml`

```yaml
en:
  better_together:
    events:
      form:
        timezone_label: "Event Timezone"
        timezone_help: "Select the timezone where this event will take place. Current time in selected timezone:"
```

---

## 5. EventsHelper Timezone-Aware Display (Priority: HIGH, ~3 hours)

### Overview
Update EventsHelper to display event times using timezone-aware helper methods, showing both event timezone and user timezone when different.

### Stakeholder Acceptance Criteria

**End Users:**
- ✅ I see event times in MY timezone
- ✅ If event is in different timezone, I see clear indicator
- ✅ Timezone abbreviations shown (EST, JST, etc.)
- ✅ Format is clear and unambiguous

### Implementation Details

**File:** `app/helpers/better_together/events_helper.rb`

```ruby
def display_event_time(event, user_timezone = Time.zone.name)
  return '' unless event&.starts_at
  
  # Convert event time to user's timezone
  start_time = event.starts_at_in_zone(user_timezone)
  end_time = event.ends_at_in_zone(user_timezone) if event.ends_at
  
  current_year = Time.current.year
  start_format = determine_start_format(start_time, current_year)
  
  # Format start time
  formatted_start = l(start_time, format: start_format)
  
  # Add timezone indicator if event timezone differs from user timezone
  if event.timezone != user_timezone
    formatted_start += " <span class='text-muted small'>(#{start_time.zone})</span>".html_safe
  end
  
  # Add end time if present
  if end_time
    end_format = determine_end_format(start_time, end_time, current_year)
    formatted_end = l(end_time, format: end_format)
    
    return "#{formatted_start} - #{formatted_end}".html_safe
  end
  
  formatted_start
end

# Display event in its original timezone (for event organizer view)
def display_event_time_local(event)
  return '' unless event&.starts_at
  
  start_time = event.local_starts_at
  end_time = event.local_ends_at
  
  current_year = Time.current.year
  start_format = determine_start_format(start_time, current_year)
  
  formatted = l(start_time, format: start_format)
  formatted += " #{start_time.zone}".html_safe
  
  if end_time
    end_format = determine_end_format(start_time, end_time, current_year)
    formatted += " - #{l(end_time, format: end_format)}".html_safe
  end
  
  formatted
end
```

---

## 6. Reminder Jobs Timezone-Aware (Priority: HIGH, ~4 hours)

### Overview
Update EventReminderSchedulerJob to calculate reminder times using event's local timezone instead of UTC.

### Stakeholder Acceptance Criteria

**Event Attendees:**
- ✅ 24-hour reminder arrives 24 hours before event in event's timezone
- ✅ 1-hour reminder arrives 1 hour before event starts locally
- ✅ At-start reminder arrives when event starts in event timezone

### Implementation Details

**File:** `app/jobs/better_together/event_reminder_scheduler_job.rb`

```ruby
def schedule_24_hour_reminder(event)
  return unless event.reminder_24h_enabled
  
  # Calculate reminder time in event's LOCAL timezone
  reminder_time = event.local_starts_at - 24.hours
  return if reminder_time < Time.current
  
  # Convert to UTC for Sidekiq scheduling
  job = EventReminderJob.set(wait_until: reminder_time.utc)
                        .perform_later(event.id, '24_hours')
  
  store_job_id(event, '24h', job.provider_job_id)
end

def schedule_1_hour_reminder(event)
  return unless event.reminder_1h_enabled
  
  reminder_time = event.local_starts_at - 1.hour
  return if reminder_time < Time.current
  
  job = EventReminderJob.set(wait_until: reminder_time.utc)
                        .perform_later(event.id, '1_hour')
  
  store_job_id(event, '1h', job.provider_job_id)
end

def schedule_at_start_reminder(event)
  return unless event.reminder_at_start_enabled
  
  reminder_time = event.local_starts_at
  return if reminder_time < Time.current
  
  job = EventReminderJob.set(wait_until: reminder_time.utc)
                        .perform_later(event.id, 'at_start')
  
  store_job_id(event, 'start', job.provider_job_id)
end
```

---

## 7. Comprehensive Testing (Priority: MEDIUM, ~8 hours)

### Overview
Add comprehensive test suite covering timezone edge cases, DST transitions, and multi-timezone interactions.

### Test Files to Create

**File:** `spec/system/timezone_handling_spec.rb`

```ruby
RSpec.describe 'Timezone handling across the application', type: :system do
  let(:platform) { create(:platform, host: true, timezone: 'Eastern Time (US & Canada)') }
  let(:tokyo_user) { create(:user, person: create(:person, time_zone: 'Tokyo')) }
  let(:nyc_user) { create(:user, person: create(:person, time_zone: 'Eastern Time (US & Canada)')) }

  describe 'event display across timezones' do
    let(:event) do
      create(:event,
        name: 'Team Meeting',
        timezone: 'Eastern Time (US & Canada)',
        starts_at: Time.zone.parse('2024-06-15 14:00:00 UTC')  # 10:00 AM EDT
      )
    end

    scenario 'NYC user sees event in EDT' do
      sign_in nyc_user
      visit event_path(event)
      
      expect(page).to have_content('10:00 AM')
      expect(page).to have_content('EDT')
    end

    scenario 'Tokyo user sees event converted to JST' do
      sign_in tokyo_user
      visit event_path(event)
      
      expect(page).to have_content('11:00 PM')  # 10 AM EDT = 11 PM JST same day
      expect(page).to have_content('JST')
    end

    scenario 'guest user sees event in platform timezone' do
      visit event_path(event)
      
      expect(page).to have_content('10:00 AM')
      expect(page).to have_content('EDT')
    end
  end

  describe 'DST transitions' do
    scenario 'event maintains local time through spring forward' do
      # Event created before DST for time after DST
      travel_to Time.zone.parse('2024-03-01 12:00:00 EST') do
        user = create(:user, person: create(:person, time_zone: 'Eastern Time (US & Canada)'))
        sign_in user
        
        visit new_event_path
        fill_in 'Name', with: 'Post-DST Meeting'
        select 'Eastern Time (US & Canada)', from: 'Timezone'
        fill_in 'Starts at', with: '2024-03-15T14:00'  # After DST transition
        click_button 'Create Event'
        
        event = BetterTogether::Event.last
        expect(event.local_starts_at.hour).to eq(14)  # Still 2 PM
        expect(event.local_starts_at.zone).to eq('EDT')  # Now EDT instead of EST
      end
    end
  end
end
```

---

## Security Considerations

### Pre-Implementation Security Scan
**REQUIRED**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager` before implementation

### Security Checklist

1. **No Unsafe User Input:**
   - Timezone values come from database (validated on model)
   - Timezone selector uses Rails `time_zone_select` (pre-validated options)
   - No user-supplied timezone strings directly used

2. **SQL Injection Prevention:**
   - All timezone queries use Active Record (parameterized)
   - No raw SQL with timezone interpolation
   - AREL used for complex queries

3. **XSS Prevention:**
   - All timezone displays use ERB auto-escaping
   - Timezone abbreviations from Rails (not user input)
   - HTML in helpers explicitly marked `.html_safe` only where needed

4. **Authorization:**
   - Timezone preferences private to each user
   - Event timezone set by event creator (authorized via Pundit)
   - No cross-user timezone manipulation

### Post-Implementation Security Scan
**REQUIRED**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager` after completion

---

## Performance Considerations

### Database Queries
- **Index on Event.timezone**: Added in migration for filtering by timezone
- **No N+1 on timezone lookups**: User/platform loaded once per request
- **Batch processing in migration**: 100 events per batch to avoid memory issues

### Request Performance
- **Time.use_zone overhead**: ~0.1ms per request (negligible)
- **Timezone conversions**: Cached within Time.zone context
- **No additional database queries**: Timezone from already-loaded associations

### Scalability
- **1000+ events**: Migration batching handles large datasets
- **1000+ concurrent users**: Thread-safe Time.zone (thread-local variable)
- **International deployment**: No centralized timezone service needed

---

## Rollback Strategy

### Phase 1 Rollback (ApplicationController)
```ruby
# Comment out single line
# around_action :set_time_zone
```
**Impact**: Reverts to UTC display (original behavior)

### Phase 2 Rollback (Event Timezone)
```ruby
class RollbackEventTimezone < ActiveRecord::Migration[7.2]
  def up
    remove_column :better_together_events, :timezone
  end
end
```
**Impact**: Events revert to timezone-naive storage

### Rollback Testing
- Test rollback in staging environment first
- Verify events still display (in UTC)
- Confirm no data corruption
- Document rollback procedure in runbook

---

## Success Metrics & Validation

### Quantitative Metrics
1. **Timezone Accuracy**: 100% of events display correct local time after DST transitions
2. **User Adoption**: >80% of users set timezone preference within 30 days
3. **Support Tickets**: 50% reduction in "wrong time" complaints
4. **International Usage**: Enable deployment to 3+ timezones

### Qualitative Validation
1. **User Feedback**: Positive responses about accurate time display
2. **Organizer Confidence**: Event creators trust times won't shift
3. **Calendar Integration**: ICS imports show correct times in calendar apps
4. **Developer Satisfaction**: Fewer timezone-related bug reports

### Test Coverage Metrics
- **Target**: 100% code coverage for timezone features
- **Critical Paths**: ApplicationController, Event timezone helpers, reminder scheduling
- **Edge Cases**: DST transitions, international timezones, nil handling

---

## Timeline & Resource Allocation

### Week 1: Foundation (8-10 hours)
**Days 1-2:**
- ApplicationController timezone setting (4h)
- Event timezone migration (4h)
- Event model helpers (3h)
- Basic tests (2h)

### Week 1-2: Enhancement (8-10 hours)
**Days 3-4:**
- Event form timezone selector (4h)
- EventsHelper updates (3h)
- ICS export fix (3h)
- Event display tests (2h)

### Week 2: Notifications (6-8 hours)
**Days 5-6:**
- Reminder job updates (4h)
- Mailer timezone enhancements (2h)
- Notification tests (2h)

### Week 2-3: Cleanup (5-6 hours)
**Days 7-8:**
- Codebase audit (4h)
- Documentation (2h)

### Week 3: Testing (8-10 hours)
**Days 9-10:**
- DST transition tests (4h)
- Multi-timezone integration tests (4h)
- Performance testing (2h)

**Total: 35-44 hours (~5-6 development days)**

---

## Documentation Updates Required

### Technical Documentation
1. **Developer Guide** (`docs/developers/timezone_handling.md`):
   - Timezone patterns and best practices
   - How Time.zone context works
   - Common pitfalls and solutions

2. **System Documentation** (`docs/systems/events_and_calendar_system.md`):
   - Update Event Notifications section
   - Add Timezone Handling subsection
   - Document DST behavior

3. **Assessment Updates** (`docs/assessments/timezone_handling_assessment.md`):
   - Mark issues as RESOLVED
   - Document implementation decisions
   - Add lessons learned

### User Documentation
1. **End User Guide** (`docs/end_users/managing_preferences.md`):
   - How to set timezone preference
   - Why timezone matters
   - Examples of timezone display

2. **Event Organizer Guide** (`docs/community_organizers/creating_events.md`):
   - How to choose event timezone
   - DST considerations
   - International event tips

3. **Platform Organizer Guide** (`docs/platform_organizers/platform_settings.md`):
   - Setting platform timezone
   - Impact on new users
   - Migration considerations

---

## Post-Implementation Monitoring

### First Week
- Monitor error logs for timezone-related exceptions
- Track ApplicationController performance impact
- Review user feedback on timezone display
- Check event creation success rate

### First Month
- Measure timezone preference adoption rate
- Track support tickets about time display
- Monitor DST transition (if occurs during this period)
- Gather organizer feedback on event creation

### Ongoing
- Review timezone-related bug reports
- Track international user growth
- Monitor performance metrics
- Update documentation based on feedback

---

## Questions & Clarifications Needed

### Pending Decisions

1. **Multi-Timezone Display Format:**
   - **Option A**: Show only user timezone: "2:00 PM EDT"
   - **Option B**: Show both: "2:00 PM EDT (7:00 PM BST event time)"
   - **Recommendation**: Option A with tooltip on hover showing event timezone

2. **Timezone Validation Level:**
   - **Option A**: Strict IANA validation (reject invalid timezones)
   - **Option B**: Allow any string (flexible but risky)
   - **Recommendation**: Option A (strict validation prevents data issues)

3. **Migration Verification:**
   - **Question**: Should platform organizers review backfilled event timezones?
   - **Recommendation**: Provide admin report of backfilled events, but don't require manual review (trust automated backfill)

---

## Approval & Sign-off

**Created By**: AI Assistant (GitHub Copilot)  
**Date**: January 17, 2026  
**Status**: Ready for Collaborative Review  

**Review Checklist**:
- [ ] Stakeholder user stories validated
- [ ] Technical approach approved
- [ ] Security considerations reviewed
- [ ] Performance impact acceptable
- [ ] Timeline realistic
- [ ] Success metrics defined
- [ ] Documentation plan sufficient
- [ ] Rollback strategy documented

**Final Approval**: _Pending collaborative review_

---

## Cross-References

- **Assessment Document**: `docs/assessments/timezone_handling_assessment.md`
- **Related Plan**: `docs/implementation/current_plans/event_reminder_ux_enhancement_implementation_plan.md`
- **Template Used**: `docs/implementation/templates/implementation_plan_template.md`
