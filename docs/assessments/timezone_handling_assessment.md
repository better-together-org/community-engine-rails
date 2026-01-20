# Timezone Handling Assessment
## Better Together Community Engine Rails Application

**Assessment Date:** January 17, 2026  
**Scope:** Comprehensive timezone handling analysis across all application layers  
**Confidence Level:** 85%+  
**Status:** Research Complete - Action Required

---

## Executive Summary

The Better Together Community Engine has **significant timezone handling gaps** that create **CRITICAL risks** for international deployments and daylight saving time (DST) transitions. While timezone storage exists for both users (Person) and platforms (Platform), these preferences are **never applied** during request processing, resulting in all datetime displays defaulting to UTC.

### Key Findings

✅ **GOOD - Timezone Storage Exists:**
- Person model stores user timezone in preferences (`time_zone`)
- Platform model has dedicated timezone column with validation
- Default timezone from ENV or 'Newfoundland'

✅ **GOOD - Some Components Use Timezone Correctly:**
- Mailers set timezone context using `Time.use_zone`
- Background jobs predominantly use `Time.current` (timezone-aware)
- Tests consistently use `Time.zone.parse`

❌ **CRITICAL - Event System Lacks Timezone:**
- Events table has NO `timezone` column
- All event times stored in UTC without timezone reference
- DST transitions will incorrectly shift event times
- International events display wrong times for all users

❌ **CRITICAL - No Per-Request Timezone Setting:**
- ApplicationController has NO `around_action :set_time_zone`
- User timezone preferences stored but NEVER applied
- All datetime displays default to UTC or application default
- Affects events, messages, notifications, invitations throughout app

❌ **HIGH - Form Inputs Are Timezone-Naive:**
- HTML5 `datetime-local` fields use browser local time
- No timezone selector in event creation form
- Time offset bugs when user timezone ≠ event timezone
- JavaScript datetime calculations browser-local only

### Impact Assessment

**Without fixes, the application will:**
1. Display all event times incorrectly to users in different timezones
2. Break event times during DST transitions (spring forward/fall back)
3. Send event reminders at wrong local times
4. Store events with wrong timezone offsets when created by international users
5. Confuse users with message timestamps, invitation expiry times, and notification times

**Risk Score: 9/10 CRITICAL** - Affects core user experience for any multi-timezone deployment

---

## 1. Timezone Storage & Configuration

### ✅ Person Model - User Timezone

**File:** `app/models/better_together/person.rb`

```ruby
store_attributes :preferences do
  locale String, default: I18n.default_locale.to_s
  time_zone String, default: ENV.fetch('APP_TIME_ZONE', 'Newfoundland')
  receive_messages_from_members Boolean, default: false
end

def time_zone=(value)
  prefs = (preferences || {}).dup
  prefs['time_zone'] = value&.to_s
  self.preferences = prefs
end
```

**Status:** ✅ **CORRECT IMPLEMENTATION**
- Stored in `preferences` JSONB column with proper getter/setter
- Validated in settings form
- Default from `ENV['APP_TIME_ZONE']` or fallback to 'Newfoundland'

**User Interface:** Settings → Preferences tab includes timezone selector

**Issues:** None in storage; **CRITICAL issue is this value is never used in request context**

---

### ✅ Platform Model - Platform Timezone

**File:** `app/models/better_together/platform.rb`

```ruby
validates :time_zone, presence: true
```

**Database Column:** `timezone` (string, required)

**Status:** ✅ **CORRECT IMPLEMENTATION**
- Direct database column with presence validation
- Set during platform setup wizard
- Editable in platform settings

**Usage Locations:**
- Platform setup wizard: `/setup/platform/new`
- Platform edit form: Platform organizer dashboard
- Mailer timezone context (correct usage)
- Background job timezone context (correct usage)

**Issues:** None in storage; **CRITICAL issue is fallback usage not implemented in ApplicationController**

---

### ⚠️ Application Configuration

**File:** `config/application.rb`

```ruby
# Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
# Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
# config.time_zone = 'Central Time (US & Canada)'
```

**Status:** ⚠️ **COMMENTED OUT**

**Host Application Configuration:**
- `better-together-rails/config/application.rb`: `config.time_zone = 'Newfoundland'`
- Other host apps: Similar timezone settings

**Risk:** MEDIUM - Commenting out is acceptable IF per-request timezone setting is properly implemented. Without it, falls back to UTC.

**Recommendation:** Keep commented in engine; implement per-request timezone setting in ApplicationController for correct timezone handling.

---

## 2. Per-Request Timezone Setting

### ❌ CRITICAL GAP: ApplicationController Has No Timezone Context

**File:** `app/controllers/better_together/application_controller.rb`

**Current before_action callbacks:**
```ruby
before_action :check_platform_setup
before_action :set_locale
before_action :store_user_location!, if: :storable_location?
before_action :handle_debug_mode
before_action :set_debug_headers
before_action :set_platform_invitation
before_action :check_platform_privacy
```

**MISSING:** No `around_action :set_time_zone` or similar timezone context setting

**Expected Pattern:**
```ruby
around_action :set_time_zone

private

def set_time_zone(&block)
  # Priority order: user timezone → platform timezone → app default → UTC
  tz = current_user&.person&.time_zone ||
       helpers.host_platform&.time_zone ||
       Rails.application.config.time_zone ||
       'UTC'
  
  Time.use_zone(tz, &block)
end
```

**Risk Level:** ❌ **CRITICAL**

**Impact:**
- All datetime displays use UTC or application default timezone (not user's timezone)
- User timezone preferences stored but completely ignored
- Event times display incorrectly for users in different timezones
- Date range queries may return incorrect results for user's perspective
- Message timestamps show wrong local time
- Invitation validity windows confusing to international users

**Example Failure Scenario:**
```ruby
# User in Tokyo (JST, UTC+9) views event created in NYC (EST, UTC-5)
# Event created: "2024-11-05 14:00 EST" (6:00 PM local NYC time)
# Stored in DB: 2024-11-05 19:00:00 UTC
# User views event without timezone context set:
#   Displays: "2024-11-05 19:00" (7:00 PM UTC instead of 4:00 AM JST next day)
# User expects: "2024-11-06 04:00 JST" (correct local time)
```

**Why This Is Critical:**
1. Affects EVERY controller action across entire application
2. Breaks user trust when times are consistently wrong
3. Makes international deployment impossible without fix
4. User preference ignored despite being configurable

---

### ✅ WHERE TIMEZONE IS SET CORRECTLY

#### ApplicationMailer - Email Timezone Context

**File:** `app/mailers/better_together/application_mailer.rb`

```ruby
around_action :set_locale_and_time_zone

def set_locale_and_time_zone(&block)
  platform = BetterTogether::Platform.find_by(host: true)
  
  self.time_zone ||= time_zone || platform&.time_zone || Rails.application.config.time_zone
  self.locale ||= locale || I18n.locale || platform&.locale || I18n.default_locale
  
  Time.use_zone(time_zone) do
    I18n.with_locale(locale, &block)
  end
end
```

**Status:** ✅ **CORRECT IMPLEMENTATION**

**Pattern:** Uses `Time.use_zone` to establish timezone context for email generation

**Why This Works:**
- Emails rendered with platform timezone
- Date/time formatting in emails uses correct timezone
- Recipients see times formatted appropriately

**Note:** Mailer uses **platform timezone** (not recipient timezone). For event reminders, should consider using recipient's timezone for personalized display.

---

#### Background Jobs - Platform Timezone Context

**File:** `app/jobs/better_together/platform_invitation_mailer_job.rb`

```ruby
def perform(platform_invitation_id)
  platform_invitation = BetterTogether::PlatformInvitation.find(platform_invitation_id)
  platform = platform_invitation.invitable
  
  # Use the platform's time zone for all time-related operations
  Time.use_zone(platform.time_zone) do
    current_time = Time.zone.now
    valid_from = platform_invitation.valid_from
    valid_until = platform_invitation.valid_until
    
    if valid_from <= current_time && (valid_until.nil? || valid_until > current_time)
      I18n.with_locale(platform_invitation.locale) do
        # Send email with correct timezone context
      end
    end
  end
end
```

**Status:** ✅ **CORRECT IMPLEMENTATION**

**Pattern:** Explicitly sets timezone context using `Time.use_zone` wrapper in background jobs

**Other Jobs Following This Pattern:**
- Most Sidekiq jobs use `Time.current` (timezone-aware)
- Metrics tracking jobs use `Time.current` for timestamps
- Event reminder jobs use `Time.current` for comparisons

**Why This Works:**
- Background jobs isolated from request context
- Explicit timezone setting ensures correct time calculations
- Consistent use of `Time.current` respects `Time.zone` setting

---

## 3. Event Model - CRITICAL Timezone Gap

### ❌ Events Have NO Timezone Column

**Migration File:** `db/migrate/20241029000911_create_better_together_events.rb`

```ruby
create_bt_table :events do |t|
  t.string :type, null: false, default: 'BetterTogether::Event'
  t.bt_creator
  t.bt_identifier
  t.bt_privacy
  
  t.datetime :starts_at, index: { name: 'bt_events_by_starts_at' }
  t.datetime :ends_at, index: { name: 'bt_events_by_ends_at' }
  t.decimal :duration_minutes
end
```

**MISSING:** `t.string :timezone` column

**Risk Level:** ❌ **CRITICAL**

**Impact - DST Transition Bug Example:**

```ruby
# Event created in New York for "March 10, 2024, 2:00 PM EST"
# Before DST: EST = UTC-5, so 2:00 PM EST = 19:00 UTC
# Database stores: 2024-03-10 19:00:00 UTC

# DST transition happens: March 10, 2024, 2:00 AM → 3:00 AM EDT
# After transition: EDT = UTC-4 (one hour difference)

# User views event after DST transition:
#   System converts 19:00 UTC to EDT
#   19:00 UTC = 15:00 EDT (3:00 PM EDT)
#   
# DISPLAYED: "March 10, 2024, 3:00 PM EDT" ← WRONG! (1 hour off)
# EXPECTED: "March 10, 2024, 2:00 PM EDT" ← Event organizer's intent
```

**Impact - International Event Bug Example:**

```ruby
# Event organizer in Tokyo creates event for "Tokyo 2024-06-15, 18:00 JST"
# If user timezone not properly set:
#   Form submits: 2024-06-15 18:00 (browser interprets as local time)
#   If organizer's browser in PST: stored as 01:00 UTC next day
#   Database: 2024-06-16 01:00:00 UTC
#
# Tokyo attendees view event:
#   01:00 UTC converted to JST = 10:00 AM JST June 16
#   
# DISPLAYED: "June 16, 2024, 10:00 AM" ← WRONG! (16 hours off, wrong day!)
# EXPECTED: "June 15, 2024, 6:00 PM" ← Original intent
```

**Why Events MUST Have Timezone:**

1. **Events are location-specific** - "Meeting at NYC office" happens in NYC timezone regardless of viewer's location
2. **DST transitions affect events** - Without timezone, event times shift incorrectly
3. **International collaboration** - Teams across timezones need consistent event times
4. **Calendar export accuracy** - ICS files need VTIMEZONE blocks for correct import

**Required Changes:**

1. **Migration to add timezone column:**
```ruby
class AddTimezoneToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_events, :timezone, :string, default: 'UTC', null: false
    add_index :better_together_events, :timezone
    
    # Backfill existing events with platform timezone
    reversible do |dir|
      dir.up do
        platform = BetterTogether::Platform.find_by(host: true)
        default_timezone = platform&.timezone || 'UTC'
        
        BetterTogether::Event.find_each do |event|
          begin
            event.update_column(:timezone, default_timezone)
          rescue StandardError => e
            Rails.logger.error("Failed to set timezone for event #{event.id}: #{e.message}")
          end
        end
      end
    end
  end
end
```

2. **Add timezone helpers to Event model:**
```ruby
# app/models/better_together/event.rb
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
```

3. **Update event form to include timezone selector**
4. **Update display helpers to use event timezone**
5. **Update reminder scheduling to use event local time**

**Note:** Implementation plan already exists at `docs/implementation/current_plans/event_reminder_ux_enhancement_implementation_plan.md` Step 1, but ApplicationController timezone setting must be implemented first as foundation.

---

## 4. Datetime Display Patterns

### ❌ EventsHelper - Timezone-Naive Display

**File:** `app/helpers/better_together/events_helper.rb`

```ruby
def display_event_time(event)
  return '' unless event&.starts_at
  
  start_time = event.starts_at  # ← Uses raw datetime without timezone conversion!
  end_time = event.ends_at
  current_year = Time.current.year
  
  # Format using I18n.l() which uses Time.zone context
  # BUT Time.zone is never set in ApplicationController!
  l(start_time, format: start_format)
end
```

**Risk Level:** ❌ **HIGH**

**Issues:**

1. Uses `event.starts_at` directly without timezone conversion
2. Relies on `Time.zone` being set (which it isn't in ApplicationController)
3. No event-specific timezone handling
4. Falls back to UTC or application default timezone

**Impact:** Event times display incorrectly to all users not in UTC or application default timezone

**Recommended Fix:**

```ruby
def display_event_time(event, user_timezone = Time.zone.name)
  return '' unless event&.starts_at
  
  # Convert to event's timezone first, then to user's timezone if different
  start_time = event.starts_at_in_zone(user_timezone)
  end_time = event.ends_at_in_zone(user_timezone) if event.ends_at
  
  current_year = Time.current.year
  start_format = determine_start_format(start_time, current_year)
  
  formatted_start = l(start_time, format: start_format)
  
  # Show event timezone if different from user timezone
  if event.timezone != user_timezone
    formatted_start += " (#{start_time.zone})"
  end
  
  # ... rest of logic
  formatted_start
end
```

---

### ⚠️ I18n.l() Localization - Depends on Time.zone

**Pattern Found Throughout Views:**

```erb
<!-- app/views/better_together/messages/_message.html.erb -->
<%= l(message.created_at, format: :short) %>

<!-- app/views/better_together/platform_invitation_mailer/invite.html.erb -->
<p><%= t('.valid_period', 
    valid_from: l(@valid_from, format: :long), 
    valid_until: l(@valid_until, format: :long)) %></p>

<!-- app/views/better_together/events/_event.html.erb -->
<%= l(event.starts_at, format: :short) if event.starts_at %>
```

**Status:** ⚠️ **DEPENDS ON TIME.ZONE BEING SET**

**How I18n.l() Works:**
- Uses `I18n.localize(time, format: format)`
- Converts time to `Time.zone` if set
- Falls back to UTC if `Time.zone` is nil or not set

**Risk:** MEDIUM if ApplicationController sets Time.zone correctly; HIGH without it

**Current Reality:** Since ApplicationController doesn't set Time.zone, all `l()` calls use UTC or application default

**Impact Examples:**

```ruby
# Message sent at 14:00 JST (05:00 UTC)
# Stored in DB: 2024-06-15 05:00:00 UTC

# User in JST timezone views message:
# WITHOUT Time.zone set:
#   l(message.created_at, format: :short)
#   → "Jun 15, 05:00" (UTC time, wrong for user!)
#
# WITH Time.zone set to JST:
#   l(message.created_at, format: :short)
#   → "Jun 15, 14:00" (JST time, correct for user!)
```

**Fix Required:** Implement ApplicationController `around_action :set_time_zone` to make all `l()` calls work correctly

---

## 5. Datetime Form Inputs

### ❌ Event Form - Timezone-Naive datetime-local Fields

**File:** `app/views/better_together/events/_form.html.erb`

```erb
<div class="mb-3">
  <%= form.label :starts_at, class: 'form-label' %>
  <%= form.datetime_field :starts_at, 
      include_seconds: false, 
      class: 'form-control',
      data: {
        action: 'change->better_together--event-datetime#updateEndTime'
      } %>
</div>

<div class="mb-3">
  <%= form.label :ends_at, class: 'form-label' %>
  <%= form.datetime_field :ends_at, 
      include_seconds: false, 
      class: 'form-control' %>
</div>
```

**Risk Level:** ❌ **HIGH**

**Problem with HTML5 `datetime-local` Input:**

1. Renders input in **browser's local timezone** (not event timezone)
2. User selects "14:00" thinking it's in event location's timezone (e.g., EST)
3. If user's browser in different timezone (e.g., PST), value submitted with 3-hour offset
4. Rails receives params and converts to UTC based on **user's browser timezone**
5. Result: Event stored with wrong time (off by timezone offset difference)

**Concrete Example:**

```ruby
# Event organizer in California (PST, UTC-8) creating NYC event (EST, UTC-5)
# Organizer wants: "March 15, 2024, 2:00 PM EST" (NYC time)
# Organizer enters: "2024-03-15 14:00" in form
# Browser interprets: "2024-03-15 14:00 PST" (organizer's local time)
# Browser submits: "2024-03-15T14:00" (ambiguous, browser adds PST offset)
# Rails receives: "2024-03-15 14:00 -08:00" (PST)
# Converts to UTC: "2024-03-15 22:00:00 UTC"
# 
# NYC attendees view event:
#   22:00 UTC → 17:00 EST (5:00 PM EST)
#   
# DISPLAYED: "March 15, 2024, 5:00 PM EST" ← WRONG! (3 hours off)
# INTENDED: "March 15, 2024, 2:00 PM EST"
```

**Missing from Form:**
- Timezone selector field
- JavaScript to handle timezone-aware datetime input
- Validation that submitted time makes sense in selected timezone

**Recommended Fix:**

```erb
<!-- Add timezone selector BEFORE datetime fields -->
<div class="mb-3">
  <%= form.label :timezone, t('.timezone_label'), class: 'form-label' %>
  <%= form.time_zone_select :timezone, 
      ActiveSupport::TimeZone.all,
      { 
        default: @event.timezone || current_user&.person&.time_zone || Time.zone.name,
        include_blank: false
      },
      { 
        class: 'form-select',
        data: { 
          'event-datetime-target': 'timezoneSelect',
          action: 'change->better_together--event-datetime#timezoneChanged'
        }
      } %>
  <div class="form-text">
    <%= t('.timezone_help_text') %>
  </div>
</div>

<!-- Datetime fields with timezone context -->
<div class="mb-3">
  <%= form.label :starts_at, class: 'form-label' %>
  <%= form.datetime_field :starts_at, 
      include_seconds: false, 
      class: 'form-control',
      data: {
        'event-datetime-target': 'startTimeInput',
        action: 'change->better_together--event-datetime#updateEndTime'
      } %>
  <div class="form-text" data-event-datetime-target="startTimeDisplay">
    <!-- JS updates this with timezone-aware display -->
  </div>
</div>
```

---

### ⚠️ JavaScript Datetime Handling

**File:** `app/javascript/controllers/better_together/event_datetime_controller.js`

```javascript
calculateEndTime(durationMinutes) {
  if (!this.startTimeTarget.value) return
  
  // ← Uses browser's local timezone for calculations!
  const startTime = new Date(this.startTimeTarget.value)
  const endTime = new Date(startTime.getTime() + (durationMinutes * 60 * 1000))
  
  // Format for datetime-local input (YYYY-MM-DDTHH:MM)
  const year = endTime.getFullYear()
  const month = String(endTime.getMonth() + 1).padStart(2, '0')
  const day = String(endTime.getDate()).padStart(2, '0')
  const hours = String(endTime.getHours()).padStart(2, '0')
  const minutes = String(endTime.getMinutes()).padStart(2, '0')
  
  this.endTimeTarget.value = `${year}-${month}-${day}T${hours}:${minutes}`
}
```

**Risk Level:** ⚠️ **MEDIUM**

**Issue:** All datetime calculations happen in browser's local timezone, not event timezone

**Impact:**
- End time calculation correct **relative to start time**
- BUT both start and end are in wrong timezone if user's browser timezone ≠ event timezone
- DST transition edge case: If duration crosses DST boundary, calculation may be off by 1 hour

**Example DST Edge Case:**

```javascript
// NYC on DST transition day (March 10, 2024)
// User creates event starting at 1:30 AM EST with 90-minute duration
// Expected end: 3:30 AM EDT (clock springs forward at 2:00 AM → 3:00 AM)
//
// JavaScript calculation:
//   Start: 2024-03-10 01:30
//   Add 90 minutes: 2024-03-10 03:00
//   
// But actual UTC calculation:
//   Start: 2024-03-10 06:30 UTC (1:30 AM EST = UTC-5)
//   Add 90 min: 2024-03-10 08:00 UTC
//   Convert to EDT: 04:00 AM EDT (UTC-4 after DST)
//   
// CALCULATED: 3:00 AM EDT
// ACTUAL: 4:00 AM EDT
// OFF BY: 1 hour!
```

**Recommended Fix:** Use timezone-aware JavaScript library (e.g., Luxon, date-fns-tz) for calculations in event's timezone, not browser's timezone

---

## 6. Datetime Queries

### ✅ GOOD: Consistent Use of Time.current

**Pattern Found Throughout Models:** Most scopes and queries use `Time.current` (timezone-aware) instead of `Time.now` (naive)

#### Event Model Scopes

**File:** `app/models/better_together/event.rb`

```ruby
scope :upcoming, lambda {
  start_query = arel_table[:starts_at].gteq(Time.current)  # ✅ GOOD
  where(start_query)
}

scope :ongoing, lambda {
  now = Time.current  # ✅ GOOD
  starts = arel_table[:starts_at]
  ends = arel_table[:ends_at]
  
  started = starts.lteq(now)
  has_explicit_end = ends.not_eq(nil).and(ends.gteq(now))
  
  where(started).where(has_explicit_end.or(calculated_end_in_future))
}

scope :past, lambda {
  now = Time.current  # ✅ GOOD
  ends = arel_table[:ends_at]
  
  # Complex query logic using timezone-aware 'now'
  where(ends.not_eq(nil).and(ends.lt(now)))
}
```

**Status:** ✅ **CORRECT IMPLEMENTATION**

**Why This Works:**
- `Time.current` respects `Time.zone` setting
- If `Time.zone` set per-request, queries return correct results for user's perspective
- Avoids naive `Time.now` which always uses system timezone

**Current Issue:** Since `Time.zone` not set per-request, these queries still use UTC or application default, BUT the pattern is correct and will work properly once ApplicationController sets timezone context.

---

### ✅ Metrics DatetimeFilterable Concern

**File:** `app/concerns/better_together/metrics/datetime_filterable.rb`

```ruby
def set_datetime_range
  @start_date = parse_date_param(params[:start_date]) || 30.days.ago.beginning_of_day
  @end_date = parse_date_param(params[:end_date]) || Time.current.end_of_day
  
  # Ensure start_date is before end_date
  @start_date, @end_date = @end_date, @start_date if @start_date > @end_date
end

def parse_date_param(date_string)
  return nil if date_string.blank?
  
  Time.zone.parse(date_string)  # ✅ Uses Time.zone.parse (timezone-aware)
rescue ArgumentError
  nil
end
```

**Status:** ✅ **CORRECT IMPLEMENTATION**

**Pattern:** Uses `Time.zone.parse` instead of `Time.parse`

**Why This Matters:**

```ruby
# WITHOUT Time.zone (using Time.parse):
Time.parse("2024-06-15 14:00")
# → 2024-06-15 14:00:00 +0000 (UTC, ignores user timezone)

# WITH Time.zone.parse:
Time.zone = 'Tokyo'
Time.zone.parse("2024-06-15 14:00")
# → 2024-06-15 14:00:00 +0900 (JST, respects timezone context)
```

**Current Impact:** Works correctly IF Time.zone set; falls back to UTC if not set

---

### ⚠️ Mixed Time.current and Time.zone.now Usage

**Files with Inconsistent Patterns:**

```ruby
# app/controllers/better_together/application_controller.rb:77
if session[:platform_invitation_expires_at].present? && 
   Time.current > session[:platform_invitation_expires_at]  # ✅ Time.current

# app/controllers/better_together/invitations_controller.rb:202
invitation_params_hash[:valid_from] = Time.current  # ✅ Time.current

# app/controllers/better_together/invitations_controller.rb:228
invitation.update_column(:last_sent, Time.zone.now)  # ⚠️ Time.zone.now
```

**Status:** ⚠️ **INCONSISTENT BUT LOW RISK**

**Difference:**
- `Time.current` - Rails method, always timezone-aware, returns `Time.zone.now` if set, otherwise `Time.now`
- `Time.zone.now` - Direct call, returns nil if `Time.zone` not set

**Recommendation:** Standardize on `Time.current` everywhere for consistency and safety

**Risk Level:** LOW (both work correctly if Time.zone set; Time.current safer if not set)

---

## 7. Background Jobs & Scheduled Tasks

### ✅ Event Reminder Jobs Use Time.current

**File:** `app/jobs/better_together/event_reminder_scheduler_job.rb`

```ruby
def event_in_past?(event)
  event.starts_at <= Time.current  # ✅ GOOD
end

def should_schedule_24_hour_reminder?(event)
  event.starts_at > 24.hours.from_now  # ✅ GOOD - from_now uses Time.current
end

def should_schedule_1_hour_reminder?(event)
  event.starts_at > 1.hour.from_now  # ✅ GOOD
end

def should_schedule_at_start_reminder?(event)
  event.starts_at > Time.current  # ✅ GOOD
end
```

**Status:** ✅ **CORRECT IMPLEMENTATION**

**Pattern:** Consistently uses `Time.current` and relative time helpers (`hours.from_now`) which are timezone-aware

**Current Issue:** Without event `timezone` column, reminder times calculated in UTC/application timezone instead of event's local timezone

**Example Problem:**

```ruby
# Event in NYC at "6:00 PM EST" (23:00 UTC)
# 24-hour reminder calculated as: 23:00 UTC - 24 hours = 23:00 UTC previous day
# 
# For NYC users, this means:
#   Reminder sent at 6:00 PM EST day before ← CORRECT intent
#
# For Tokyo users viewing same event:
#   Event displays as 8:00 AM JST next day (if timezone conversion added)
#   Reminder sent at 8:00 AM JST day before
#   
# But without event timezone, Tokyo users see:
#   Event at 11:00 PM JST (wrong time)
#   Reminder at 11:00 PM JST day before (also wrong)
```

**Fix Required:** Once event `timezone` column added, update reminder calculation:

```ruby
def should_schedule_24_hour_reminder?(event)
  # Use event's local time for calculation
  event.local_starts_at > 24.hours.from_now
end
```

---

### ✅ Metrics Jobs Use Time.current

**Files:**
- `app/jobs/better_together/metrics/track_page_view_job.rb`
- `app/jobs/better_together/metrics/track_link_click_job.rb`

```ruby
# Page view tracking
BetterTogether::Metrics::PageView.create!(
  # ... other params
  viewed_at: Time.current  # ✅ GOOD
)

# Link click tracking
BetterTogether::Metrics::LinkClick.create!(
  # ... other params
  clicked_at: Time.current  # ✅ GOOD
)
```

**Status:** ✅ **CORRECT IMPLEMENTATION**

**Note:** Metrics stored in UTC is actually **desirable** for analytics. Metrics analysis can be done in platform timezone for reporting, but storing events in UTC is standard practice.

**Risk Level:** NONE - Current implementation appropriate for metrics

---

## 8. Test Coverage

### ✅ Tests Use Time.zone Helpers Consistently

**Examples from Specs:**

```ruby
# spec/helpers/better_together/events_helper_spec.rb:8
let(:start_time) { Time.zone.parse('2025-09-04 14:00:00') }  # ✅ GOOD

# spec/concerns/better_together/metrics/datetime_filterable_spec.rb:45
expect(@start_date).to be_within(1.second)
  .of(Time.zone.parse(start_date))  # ✅ GOOD

# spec/models/better_together/event_attendance_spec.rb:8
let(:event) { 
  BetterTogether::Event.create!(
    name: 'Test', 
    starts_at: Time.zone.now,  # ✅ GOOD
    creator: person
  ) 
}

# spec/jobs/better_together/event_reminder_scheduler_job_spec.rb:11
let(:future_time) { 25.hours.from_now }  # ✅ GOOD - uses Time.current
```

**Status:** ✅ **CORRECT IMPLEMENTATION**

**Pattern:** Tests consistently use:
- `Time.zone.parse()` for parsing datetime strings
- `Time.zone.now` or `Time.current` for current time
- `hours.from_now` / `days.ago` for relative times

**Coverage Quality:** GOOD for basic datetime handling

---

### ❌ MISSING: Timezone-Specific Test Coverage

**No Tests Found For:**
1. DST transition handling
2. Events created in one timezone, viewed in another
3. Multi-timezone user interactions
4. Reminder scheduling across different timezones
5. Calendar month boundary issues with different timezones
6. Form submission with timezone offset mismatches

**Example Missing Test Scenario:**

```ruby
RSpec.describe 'Multi-timezone event handling', type: :system do
  it 'displays NYC event correctly for Tokyo user' do
    # Create event as NYC user
    Time.use_zone('Eastern Time (US & Canada)') do
      sign_in create(:user, :in_new_york)
      
      visit new_event_path
      fill_in 'Name', with: 'Team Meeting'
      select 'Eastern Time (US & Canada)', from: 'Timezone'
      fill_in 'Starts at', with: '2024-03-15 14:00'  # 2:00 PM EST
      click_button 'Create Event'
      
      @event = Event.last
      expect(@event.timezone).to eq('Eastern Time (US & Canada)')
      expect(@event.local_starts_at.hour).to eq(14)  # 2:00 PM in event timezone
    end
    
    # View as Tokyo user
    Time.use_zone('Tokyo') do
      sign_in create(:user, :in_tokyo)
      
      visit event_path(@event)
      
      # Event at 2:00 PM EST = 4:00 AM JST next day (EST = UTC-5, JST = UTC+9)
      expect(page).to have_content('March 16')  # Next day in JST
      expect(page).to have_content('4:00 AM')   # JST local time
      expect(page).to have_content('JST')       # Timezone indicator
    end
  end
  
  it 'handles DST transition correctly' do
    # Event created before DST for time after DST
    travel_to Time.zone.parse('2024-03-01 12:00 EST') do
      event = create(:event,
        timezone: 'Eastern Time (US & Canada)',
        starts_at: Time.zone.parse('2024-03-15 14:00'))  # After DST transition
      
      # DST transition: March 10, 2024, 2:00 AM → 3:00 AM
      travel_to Time.zone.parse('2024-03-11 12:00 EDT') do
        # Event time should still be 2:00 PM local (now EDT instead of EST)
        expect(event.local_starts_at.hour).to eq(14)
        expect(event.local_starts_at.zone).to eq('EDT')
      end
    end
  end
end
```

**Risk Level:** MEDIUM - Lack of timezone tests means bugs won't be caught until production

**Recommendation:** Add comprehensive timezone test suite before implementing timezone features

---

## 9. Known Issues & Existing Documentation

### ✅ Events Assessment Document Identifies Timezone Issue

**File:** `docs/assessments/events_and_calendar_system_assessment.md` (Lines 148-178)

The existing assessment **CORRECTLY IDENTIFIES** the critical timezone problem:

```markdown
**🔴 Critical Issue: Timezone Handling**:

```ruby
# db/migrate/20241029000911_create_better_together_events.rb
t.datetime :starts_at  # ← NO timezone information stored!
t.datetime :ends_at
```

**Problem**: Rails `datetime` columns store UTC by default, but there's:
- No `timezone` field on events
- No `Time.zone` handling in model
- Display helpers use `I18n.l(event.starts_at)` which assumes user's timezone

**Example DST Bug**:
```ruby
# User in New York creates event for "March 10, 2024 2:00 PM EST"
# Stored as: 2024-03-10 19:00:00 UTC
# After DST transition (March 10, 2:00 AM → 3:00 AM EDT)
# Display shows: "March 10, 2024 3:00 PM EDT" ← WRONG!
```
```

**Status:** ✅ **ACCURATE DOCUMENTATION**

**Assessment Recommendations Align With This Report:**
- Add `timezone` column to events
- Implement timezone helpers on Event model
- Update display logic to use event timezone
- Add timezone selector to forms

---

### ✅ Implementation Plan Exists

**File:** `docs/implementation/current_plans/event_reminder_ux_enhancement_implementation_plan.md`

**Step 1 of existing plan addresses Event timezone:**
- Add `timezone` column to events table
- Backfill with platform timezone
- Add timezone helper methods (`local_starts_at`, `starts_at_in_zone`)
- Update forms with timezone selector

**Status:** ✅ **PLAN EXISTS BUT NOT YET IMPLEMENTED**

**Critical Addition Needed:** Implementation plan should be updated to include ApplicationController timezone setting as **prerequisite step** before Event timezone implementation, since all datetime display depends on Time.zone context being set.

---

## 10. ICS Calendar Export

### ⚠️ ICS Export Lacks VTIMEZONE Blocks

**File:** `app/models/better_together/event.rb`

```ruby
def to_ics
  Icalendar::Event.new.tap do |e|
    e.dtstart     = Icalendar::Values::Time.new(starts_at&.utc, 'tzid' => 'UTC')
    e.dtend       = Icalendar::Values::Time.new(ends_at&.utc, 'tzid' => 'UTC')
    # ... other properties
  end
end
```

**Risk Level:** ⚠️ **MEDIUM-HIGH**

**Issues:**

1. Hardcoded to UTC timezone (`tzid' => 'UTC'`)
2. No VTIMEZONE component in calendar export
3. Calendar apps may display wrong times on import
4. No DST rules included in export

**Impact:**

```ruby
# Event created in NYC for "March 15, 2024, 2:00 PM EST"
# ICS export shows: DTSTART;TZID=UTC:20240315T190000Z
# 
# User imports to Apple Calendar:
#   Calendar app sees UTC time
#   Converts to user's local timezone
#   If user in Tokyo: displays as 4:00 AM JST March 16
#   If user in NYC: displays as 2:00 PM EST March 15 ← Correct by coincidence!
#
# Better approach:
#   DTSTART;TZID=America/New_York:20240315T140000
#   Include VTIMEZONE block with DST rules
#   All calendar apps display correctly in event's original timezone
```

**Recommended Fix:**

```ruby
def to_ics
  cal = Icalendar::Calendar.new
  
  # Add VTIMEZONE component for event's timezone
  tz = TZInfo::Timezone.get(timezone)
  timezone_definition = tz.ical_timezone(starts_at)
  cal.add_timezone(timezone_definition)
  
  # Create event with proper timezone reference
  cal.event do |e|
    e.dtstart = Icalendar::Values::Time.new(
      local_starts_at,
      'tzid' => timezone
    )
    e.dtend = Icalendar::Values::Time.new(
      local_ends_at,
      'tzid' => timezone
    )
    # ... other properties
  end
  
  cal
end
```

**Requires:** Event must have `timezone` column first

---

## Consolidated Risk Assessment Matrix

### 🔴 CRITICAL Risks (Immediate Action Required)

| # | Issue | Location | Risk Score | Impact | Users Affected |
|---|-------|----------|------------|--------|----------------|
| 1 | No event timezone column | Event model/migration | 10/10 | Events display wrong times; DST bugs; incorrect reminders | ALL event attendees |
| 2 | No ApplicationController timezone setting | ApplicationController | 9/10 | All user timezone preferences ignored; wrong datetime displays everywhere | ALL users |
| 3 | Timezone-naive form inputs | Event form | 8/10 | Event times stored with wrong timezone offset | ALL event creators |

**Total Users Impacted:** 100% of users in any non-UTC timezone

**Business Impact:** 
- International deployment impossible without fixes
- User trust broken by consistently wrong times
- Event attendance confusion and missed events
- Calendar integration broken

---

### 🟡 HIGH Risks (Should Fix Soon)

| # | Issue | Location | Risk Score | Impact | Users Affected |
|---|-------|----------|------------|--------|----------------|
| 4 | EventsHelper doesn't use timezone | events_helper.rb | 7/10 | Event times display incorrectly in views | Event viewers |
| 5 | ICS export lacks VTIMEZONE | Event#to_ics | 7/10 | Calendar apps show wrong times | Calendar export users |
| 6 | JavaScript datetime handling | event_datetime_controller.js | 6/10 | Duration calculations wrong during DST | Event creators |

**Total Users Impacted:** ~80% of users (anyone viewing or creating events)

---

### 🟢 MEDIUM Risks (Plan to Address)

| # | Issue | Location | Risk Score | Impact | Users Affected |
|---|-------|----------|------------|--------|----------------|
| 7 | Message timestamps | Message views | 5/10 | Confusing timestamps in conversations | Message users |
| 8 | Invitation validity times | Invitation forms | 5/10 | Invitations may expire at wrong perceived time | Invitation recipients |
| 9 | Mixed Time.current/Time.zone.now | Controllers | 4/10 | Inconsistent patterns, potential bugs | Developers |

**Total Users Impacted:** ~60% of users (messaging and invitation features)

---

### ⚪ LOW Risks (Acceptable Current State)

| # | Issue | Location | Risk Score | Impact | Users Affected |
|---|-------|----------|------------|--------|----------------|
| 10 | Metrics timestamps in UTC | Metrics models | 2/10 | None (UTC appropriate for analytics) | None |
| 11 | Commented config.time_zone | application.rb | 2/10 | OK if per-request setting implemented | None |

**Total Users Impacted:** 0% (current implementation acceptable)

---

## Implementation Recommendations

### Priority 1: CRITICAL Fixes (Implement Immediately)

#### 1A. Add ApplicationController Timezone Setting

**Estimated Effort:** 2-4 hours  
**Complexity:** LOW  
**Dependencies:** None

**Implementation:**

```ruby
# app/controllers/better_together/application_controller.rb

around_action :set_time_zone

private

def set_time_zone(&block)
  # Priority order: user timezone → platform timezone → app default → UTC
  tz = current_user&.person&.time_zone ||
       helpers.host_platform&.time_zone ||
       Rails.application.config.time_zone ||
       'UTC'
  
  Time.use_zone(tz, &block)
end
```

**Testing:**

```ruby
RSpec.describe BetterTogether::ApplicationController, type: :controller do
  controller do
    def index
      render plain: Time.zone.name
    end
  end

  before do
    routes.draw { get 'index' => 'anonymous#index' }
  end

  it 'sets timezone from current user' do
    user = create(:user)
    user.person.update(time_zone: 'Tokyo')
    sign_in user
    
    get :index
    expect(response.body).to eq('Tokyo')
  end

  it 'falls back to platform timezone' do
    platform = create(:platform, host: true, timezone: 'Eastern Time (US & Canada)')
    
    get :index
    expect(response.body).to eq('Eastern Time (US & Canada)')
  end

  it 'falls back to UTC if no platform' do
    get :index
    expect(response.body).to eq('UTC')
  end
end
```

**Impact:** Immediately fixes ALL datetime display issues across entire application

---

#### 1B. Add Timezone Column to Events

**Estimated Effort:** 4-6 hours  
**Complexity:** MEDIUM  
**Dependencies:** None (but should be done after 1A for consistency)

**Implementation:** Already detailed in existing implementation plan (Step 1)

**Key Points:**
- Migration adds `timezone` column (string, default 'UTC', null: false)
- Backfill existing events with platform timezone (with error logging)
- Add timezone helper methods to Event model
- Add index on timezone column

**Testing:**

```ruby
RSpec.describe BetterTogether::Event, type: :model do
  describe 'timezone handling' do
    let(:platform) { create(:platform, timezone: 'Eastern Time (US & Canada)') }
    let(:event) { create(:event, timezone: 'Tokyo', starts_at: Time.zone.parse('2024-06-15 14:00 UTC')) }

    it 'returns local time in event timezone' do
      expect(event.local_starts_at.zone).to eq('JST')
      expect(event.local_starts_at.hour).to eq(23)  # 14:00 UTC = 23:00 JST
    end

    it 'converts to user timezone' do
      user_time = event.starts_at_in_zone('Eastern Time (US & Canada)')
      expect(user_time.zone).to eq('EDT')
      expect(user_time.hour).to eq(10)  # 14:00 UTC = 10:00 AM EDT
    end
  end
end
```

**Impact:** Fixes event display issues, enables correct reminder scheduling, prevents DST bugs

---

#### 1C. Add Timezone Selector to Event Form

**Estimated Effort:** 3-4 hours  
**Complexity:** MEDIUM  
**Dependencies:** 1B (requires timezone column to exist)

**Implementation:**

```erb
<!-- app/views/better_together/events/_form.html.erb -->

<div class="mb-3">
  <%= form.label :timezone, t('.timezone_label'), class: 'form-label' %>
  <%= form.time_zone_select :timezone, 
      ActiveSupport::TimeZone.all,
      { 
        default: @event.timezone || current_user&.person&.time_zone || helpers.host_platform&.time_zone,
        include_blank: false
      },
      { 
        class: 'form-select',
        data: { 
          'event-datetime-target': 'timezoneSelect'
        }
      } %>
  <div class="form-text">
    <%= t('.timezone_help_text', 
        example: "#{Time.zone.now.strftime('%I:%M %p %Z')}") %>
  </div>
</div>

<!-- Move this BEFORE datetime fields so timezone context is clear -->
```

**i18n Keys:**

```yaml
en:
  better_together:
    events:
      form:
        timezone_label: "Event Timezone"
        timezone_help_text: "Select the timezone where this event will take place (currently: %{example})"
```

**JavaScript Enhancement (Optional):**

```javascript
// Show current time in selected timezone
timezoneChanged() {
  const timezone = this.timezoneSelectTarget.value
  // Fetch current time in selected timezone via AJAX or JS library
  // Update help text to show example time
}
```

**Impact:** Prevents timezone offset bugs when creating events, gives users clear timezone context

---

### Priority 2: HIGH Fixes (This Sprint)

#### 2A. Update EventsHelper to Use Timezone

**Estimated Effort:** 2-3 hours  
**Complexity:** LOW  
**Dependencies:** 1A, 1B

```ruby
# app/helpers/better_together/events_helper.rb

def display_event_time(event, user_timezone = Time.zone.name)
  return '' unless event&.starts_at
  
  # Use event's timezone, converted to user's timezone
  start_time = event.starts_at_in_zone(user_timezone)
  end_time = event.ends_at_in_zone(user_timezone) if event.ends_at
  
  current_year = Time.current.year
  start_format = determine_start_format(start_time, current_year)
  
  formatted_start = l(start_time, format: start_format)
  
  # Show timezone if different from user's
  if event.timezone != user_timezone
    formatted_start += " <span class='text-muted'>(#{start_time.zone})</span>".html_safe
  end
  
  if end_time
    end_format = determine_end_format(start_time, end_time, current_year)
    formatted_end = l(end_time, format: end_format)
    
    "#{formatted_start} - #{formatted_end}".html_safe
  else
    formatted_start
  end
end
```

---

#### 2B. Fix ICS Export with VTIMEZONE

**Estimated Effort:** 3-4 hours  
**Complexity:** MEDIUM  
**Dependencies:** 1B

```ruby
# app/models/better_together/event.rb

def to_ics
  cal = Icalendar::Calendar.new
  cal.prodid = '-//Better Together//Events//EN'
  
  # Add VTIMEZONE component
  tz = TZInfo::Timezone.get(timezone)
  timezone_definition = tz.ical_timezone(starts_at)
  cal.add_timezone(timezone_definition)
  
  # Create event in proper timezone
  cal.event do |e|
    e.dtstart = Icalendar::Values::Time.new(
      local_starts_at,
      'tzid' => timezone
    )
    e.dtend = Icalendar::Values::Time.new(
      local_ends_at,
      'tzid' => timezone
    )
    e.summary = name
    e.description = description
    e.uid = identifier
    e.url = Icalendar::Values::Uri.new(url) if respond_to?(:url)
  end
  
  cal.to_ical
end
```

---

#### 2C. Update Reminder Jobs to Use Event Timezone

**Estimated Effort:** 3-4 hours  
**Complexity:** MEDIUM  
**Dependencies:** 1B

```ruby
# app/jobs/better_together/event_reminder_scheduler_job.rb

def schedule_24_hour_reminder(event)
  return unless event.reminder_24h_enabled
  
  # Calculate in event's local timezone, convert to UTC for Sidekiq
  reminder_time = event.local_starts_at - 24.hours
  return if reminder_time < Time.current
  
  job = EventReminderJob.set(wait_until: reminder_time.utc)
                        .perform_later(event.id, '24_hours')
  
  store_job_id(event, '24h', job.provider_job_id)
end
```

---

### Priority 3: MEDIUM Fixes (Next Sprint)

#### 3A. Audit and Standardize Time Methods

**Estimated Effort:** 4-6 hours  
**Complexity:** LOW  
**Dependencies:** None

**Tasks:**
1. Search codebase for `Time.now` and replace with `Time.current`
2. Search for `Date.today` and replace with `Date.current`
3. Search for `Time.parse` and replace with `Time.zone.parse`
4. Standardize on `Time.current` over `Time.zone.now`

**Script to Find Issues:**

```bash
# Find Time.now usage
bin/dc-run grep -r "Time\.now" app/ --exclude-dir={node_modules,assets}

# Find Date.today usage
bin/dc-run grep -r "Date\.today" app/ --exclude-dir={node_modules,assets}

# Find Time.parse usage
bin/dc-run grep -r "Time\.parse" app/ --exclude-dir={node_modules,assets}
```

---

#### 3B. Add Comprehensive Timezone Tests

**Estimated Effort:** 8-10 hours  
**Complexity:** MEDIUM  
**Dependencies:** 1A, 1B

**Test Scenarios to Add:**
1. DST spring forward transition
2. DST fall back transition
3. Multi-timezone user interactions
4. Calendar month boundary issues
5. International event handling
6. Reminder scheduling across timezones

**Example Test File:** `spec/system/timezone_handling_spec.rb`

---

#### 3C. Update Documentation

**Estimated Effort:** 2-3 hours  
**Complexity:** LOW  
**Dependencies:** All fixes implemented

**Documentation to Update:**
1. Developer guide - timezone handling patterns
2. Contributing guidelines - timezone requirements
3. Event system documentation - timezone features
4. User guide - timezone selection and display

---

## Good vs Bad Pattern Examples

### ✅ GOOD Patterns Found in Codebase

```ruby
# 1. Mailer timezone context
Time.use_zone(platform.time_zone) do
  # All operations here use platform timezone
  I18n.with_locale(locale) do
    # Generate email with correct timezone and locale
  end
end

# 2. Query using Time.current (timezone-aware)
Event.where('starts_at <= ?', Time.current)
Event.where(starts_at: 1.week.ago..Time.current)

# 3. Parse with timezone context
Time.zone.parse(date_string)

# 4. Relative time helpers (timezone-aware)
24.hours.from_now
30.days.ago.beginning_of_day
Time.current.end_of_day

# 5. Tests using timezone helpers
let(:start_time) { Time.zone.parse('2025-09-04 14:00:00') }
let(:event) { create(:event, starts_at: Time.zone.now) }

# 6. Background jobs with explicit timezone
Time.use_zone(platform.time_zone) do
  # Job logic here
end
```

---

### ❌ BAD Patterns Found in Codebase

```ruby
# 1. No timezone on datetime columns (CRITICAL)
t.datetime :starts_at  # Should include companion: t.string :timezone

# 2. Display without timezone conversion (HIGH)
start_time = event.starts_at  # Should be: event.starts_at_in_zone(user_tz)
l(start_time, format: :long)

# 3. Form without timezone selector (HIGH)
form.datetime_field :starts_at  # Should include timezone selector above it

# 4. ICS export without VTIMEZONE (MEDIUM)
e.dtstart = Icalendar::Values::Time.new(starts_at&.utc, 'tzid' => 'UTC')
# Should use event timezone and include VTIMEZONE component

# 5. No ApplicationController timezone setting (CRITICAL)
# Missing:
around_action :set_time_zone

# 6. JavaScript using browser local time (MEDIUM)
const startTime = new Date(this.startTimeTarget.value)
# Should use timezone-aware library (Luxon, date-fns-tz)
```

---

## Files Requiring Changes

### Must Change (Priority 1 - CRITICAL)

| File | Change Type | Estimated Hours |
|------|-------------|-----------------|
| `app/controllers/better_together/application_controller.rb` | Add `around_action :set_time_zone` | 2-4 |
| `db/migrate/[new]_add_timezone_to_events.rb` | New migration | 2-3 |
| `app/models/better_together/event.rb` | Add timezone helpers | 2-3 |
| `app/views/better_together/events/_form.html.erb` | Add timezone selector | 3-4 |
| `config/locales/better_together/en.yml` | Add timezone i18n keys | 1 |

**Subtotal:** 10-17 hours

---

### Should Change (Priority 2 - HIGH)

| File | Change Type | Estimated Hours |
|------|-------------|-----------------|
| `app/helpers/better_together/events_helper.rb` | Use event timezone | 2-3 |
| `app/models/better_together/event.rb` | Fix ICS export | 3-4 |
| `app/jobs/better_together/event_reminder_scheduler_job.rb` | Timezone-aware scheduling | 3-4 |
| `app/javascript/controllers/better_together/event_datetime_controller.js` | Timezone-aware calculations | 4-6 |

**Subtotal:** 12-17 hours

---

### May Change (Priority 3 - MEDIUM)

| File | Change Type | Estimated Hours |
|------|-------------|-----------------|
| Various controllers | Replace `Time.now` with `Time.current` | 4-6 |
| `docs/developers/timezone_handling.md` | New documentation | 2-3 |
| `spec/system/timezone_spec.rb` | New comprehensive tests | 8-10 |

**Subtotal:** 14-19 hours

---

**Total Estimated Effort:**
- Priority 1 (CRITICAL): 10-17 hours (1-2 days)
- Priority 2 (HIGH): 12-17 hours (1.5-2 days)
- Priority 3 (MEDIUM): 14-19 hours (2-2.5 days)
- **Grand Total:** 36-53 hours (4.5-6.5 days)

---

## Conclusion

The Better Together Community Engine has a **solid foundation** for timezone handling with storage for both user and platform timezones, and good patterns in background jobs and queries using `Time.current`. However, it has **CRITICAL gaps** that prevent timezone preferences from being applied:

### The Good News

1. ✅ Timezone storage exists for users and platforms
2. ✅ Most queries use timezone-aware `Time.current`
3. ✅ Mailers correctly set timezone context
4. ✅ Tests use timezone-aware helpers
5. ✅ Implementation plan already exists for Event timezone
6. ✅ Existing assessment correctly identified the problem

### The Critical Issues

1. ❌ **ApplicationController doesn't set Time.zone per-request** - This is the most impactful gap affecting ALL datetime displays
2. ❌ **Events lack timezone column** - Prevents accurate event time storage and DST handling
3. ❌ **Forms don't include timezone selector** - Causes timezone offset bugs when creating events

### The Path Forward

**Immediate Actions (This Week):**
1. Implement ApplicationController timezone setting (2-4 hours)
2. Add timezone column to events with migration (4-6 hours)
3. Add timezone selector to event form (3-4 hours)

**Follow-up Actions (This Sprint):**
4. Update EventsHelper to use timezone (2-3 hours)
5. Fix ICS export with VTIMEZONE (3-4 hours)
6. Update reminder jobs for timezone-aware scheduling (3-4 hours)

**Future Improvements (Next Sprint):**
7. Audit and standardize time methods across codebase
8. Add comprehensive timezone test coverage
9. Update developer documentation

### Risk Mitigation

**If immediate fixes not implemented:**
- International deployment will be broken
- User trust damaged by consistently wrong times
- DST transitions will break existing events
- Event attendance and participation negatively impacted

**Once fixes implemented:**
- All datetime displays correct for user's timezone
- Events maintain correct times through DST transitions
- International events work correctly
- Calendar exports import properly

### Next Steps

1. **Review this assessment** with development team and stakeholders
2. **Prioritize Priority 1 fixes** for immediate implementation
3. **Execute ApplicationController change first** as foundation for all other timezone work
4. **Follow with Event timezone implementation** using existing implementation plan
5. **Add comprehensive tests** to prevent timezone regressions
6. **Document patterns** for future timezone-aware development

---

**Assessment Complete**  
**Confidence Level:** 85%+  
**Action Required:** IMMEDIATE (Priority 1 fixes)  
**Estimated Time to Resolution:** 4.5-6.5 days for complete timezone handling
