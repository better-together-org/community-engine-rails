# Events Feature Review & Improvement Plan

<!-- historical-doc-banner -->
> **Historical document.** Written on 2025-11-05 (last edited 2025-12-15). It records the code, plans and findings as they stood then and is not maintained for later releases. For current behaviour see the [documentation index](../table_of_contents.md).
<!-- /historical-doc-banner -->

**Better Together Community Engine - Rails**

**Date:** November 5, 2025  
**Status:** Assessment & Planning Phase  
**Scope:** Full Events system review with actionable improvements

---

## Executive Summary

The Events feature is a **mature, well-architected system** with strong foundations in Hotwire, accessibility, and security. This review identifies opportunities to enhance performance, add missing features, and improve developer experience without compromising the existing quality.

**Overall Assessment:** 🟢 **Good** - Production-ready with room for optimization

---

## Table of Contents

1. [Architecture Review](#1-architecture-review)
2. [Feature Completeness](#2-feature-completeness)
3. [Performance & Scalability](#3-performance--scalability)
4. [Accessibility & UI/UX](#4-accessibility--uiux)
5. [Security & Permissions](#5-security--permissions)
6. [Internationalization](#6-internationalization)
7. [Testing & Documentation](#7-testing--documentation)
8. [Prioritized Recommendations](#8-prioritized-recommendations)
9. [Implementation Roadmap](#9-implementation-roadmap)

---

## 1. Architecture Review

### Current Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend Layer                            │
│  • Event listings, detail pages, forms                          │
│  • Stimulus controllers (hover cards, datetime sync)            │
│  • Bootstrap 5 components with ARIA                             │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Controller Layer                           │
│  • EventsController (CRUD + RSVP + ICS export)                  │
│  • Events::InvitationsController (invitation management)        │
│  • Concerns: InvitationTokenAuthorization, NotificationReadable │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Model Layer                              │
│  • Event (main model with 20+ concerns)                         │
│  • EventAttendance (RSVP tracking)                              │
│  • EventHost (polymorphic hosting)                              │
│  • EventInvitation (token-based invites)                        │
│  • EventCategory (categorization)                               │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Background Processing                         │
│  • EventReminderJob (24h + 1h notifications)                    │
│  • EventReminderSchedulerJob (schedules reminders)              │
│  • EventReminderScanJob (finds upcoming events)                 │
│  • Geography::GeocodingJob (address geocoding)                  │
└─────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Notification System                           │
│  • EventInvitationNotifier (in-app + email)                     │
│  • EventReminderNotifier (24h + 1h reminders)                   │
│  • EventUpdateNotifier (significant changes)                    │
│  • Noticed gem integration                                      │
└─────────────────────────────────────────────────────────────────┘
```

### ✅ Strengths

1. **Excellent Separation of Concerns**
   - Controllers remain thin (341 lines, but well-organized)
   - Business logic properly distributed across models and jobs
   - Concerns used appropriately for cross-cutting features

2. **Strong Hotwire Integration**
   - Turbo Frames for partial page updates
   - Stimulus controllers for interactivity
   - No unnecessary JavaScript dependencies

3. **Comprehensive Policy Layer**
   - Pundit policies for all actions
   - Complex authorization logic well-encapsulated
   - Invitation token integration in policies

4. **Well-Structured Models**
   - Event model uses concerns appropriately
   - Polymorphic associations for flexibility
   - String enums for readability

5. **Robust Background Job System**
   - Sidekiq-based reminder system
   - Proper job scheduling and error handling
   - Multiple reminder intervals (24h, 1h)

### ⚠️ Areas for Improvement

#### 1.1 Controller Complexity

**Issue:** EventsController at 341 lines with multiple concerns

**Impact:** Medium - Maintainability concern but well-organized

**Current Code Structure:**
```ruby
class EventsController < FriendlyResourceController
  include InvitationTokenAuthorization
  include NotificationReadable
  
  # 15+ action methods
  # 10+ private helper methods
  # Complex privacy check override
end
```

**Recommendation:**
```ruby
# Extract RSVP logic to separate controller
class Events::RsvpController < ApplicationController
  def interested; end
  def going; end
  def cancel; end
end

# Extract ICS export to concern or service
module Events::IcsExportable
  extend ActiveSupport::Concern
  
  def to_ics_calendar
    # ICS generation logic
  end
end
```

#### 1.2 Naming Inconsistencies

**Issue:** Mixed terminology for similar concepts

**Examples:**
- `set_resource_instance` vs `@event` usage
- `resource_instance` vs `@resource` in views
- `helpers.current_person` vs `agent` in policies

**Recommendation:** Establish naming conventions document

#### 1.3 Redundant Preloading Logic

**Issue:** `preload_event_associations!` method duplicates policy scope eager loading

**Current:**
```ruby
# In EventsController
def preload_event_associations!
  @event.categories.includes(:string_translations).load
  @event.event_hosts.includes(:host).load
  # ... more preloading
end

# In EventPolicy::Scope
def resolve
  scope.with_attached_cover_image
       .includes(:string_translations, :location, :event_hosts, ...)
end
```

**Recommendation:** Consolidate into a single source of truth

---

## 2. Feature Completeness

### ✅ Implemented Features

#### Core CRUD
- ✅ Create, read, update, delete events
- ✅ Draft events (events without start time)
- ✅ Scheduled events (with start time)
- ✅ Privacy levels (public/private)
- ✅ Cover images with Active Storage
- ✅ Rich text descriptions (Action Text)
- ✅ Duration tracking (minutes)
- ✅ Registration URL (external ticketing)

#### RSVP System
- ✅ "Interested" status
- ✅ "Going" status with calendar integration
- ✅ RSVP cancellation
- ✅ Attendance counts display
- ✅ Draft event RSVP prevention

#### Invitations
- ✅ Token-based invitations
- ✅ Email delivery
- ✅ In-app notifications
- ✅ Privacy bypass for valid tokens
- ✅ Expiration handling
- ✅ Accept/decline workflow

#### Hosting
- ✅ Polymorphic event hosts
- ✅ Multiple hosts per event
- ✅ Host authorization
- ✅ Visible host display

#### Location System
- ✅ Polymorphic location (Address, Building)
- ✅ Background geocoding
- ✅ Location selector in forms
- ✅ Map integration ready (PostGIS)

#### Categories
- ✅ Multi-category support
- ✅ Category badges
- ✅ Translated category names

#### Notifications
- ✅ Invitation notifications
- ✅ Event reminders (24h, 1h)
- ✅ Update notifications
- ✅ Email + in-app delivery

#### Export
- ✅ ICS calendar export
- ✅ Individual event .ics files
- ✅ UTF-8 encoding

### ❌ Missing Features

#### 2.1 Event Filtering & Search

**Priority:** 🔴 High  
**User Impact:** High - Hard to discover events

**Missing:**
- Date range filters
- Category filters
- Location-based search
- Keyword search
- Host filters
- RSVP status filters (my events)

**Recommendation:**
```ruby
# Add to EventsController
def index
  @events = policy_scope(Event)
  @events = EventFilterService.new(@events, params).filter
  # Apply scopes based on filter params
end

# Service object for complex filtering
class EventFilterService
  def filter
    apply_date_filters
    apply_category_filters
    apply_location_filters
    apply_search_query
    scope
  end
end
```

#### 2.2 Recurring Events

**Priority:** 🟡 Medium  
**User Impact:** Medium - Common use case

**Missing:**
- Recurrence rules (daily, weekly, monthly)
- Recurrence end dates
- Exception dates (holidays)
- Series management

**Recommendation:**
```ruby
# Add to Event model
belongs_to :recurrence_rule, optional: true
belongs_to :parent_event, class_name: 'Event', optional: true
has_many :child_events, class_name: 'Event', foreign_key: :parent_event_id

# New model
class RecurrenceRule
  # frequency: daily, weekly, monthly, yearly
  # interval: every N periods
  # until: end date
  # exceptions: array of dates to skip
end
```

**Note:** This is a significant feature requiring careful design

#### 2.3 Attendee Management UI

**Priority:** 🟡 Medium  
**User Impact:** Medium - Organizers need this

**Missing:**
- Attendee list export (CSV)
- Check-in functionality
- Waitlist support
- Attendance capacity limits
- Attendee messaging

**Recommendation:**
```ruby
# Add to Event model
attribute :capacity, :integer
attribute :waitlist_enabled, :boolean

def at_capacity?
  capacity.present? && attendees.count >= capacity
end

# New controller action
def export_attendees
  csv = EventAttendeeCsvExporter.new(@event).export
  send_data csv, filename: "#{@event.slug}-attendees.csv"
end
```

#### 2.4 Calendar Integration

**Priority:** 🟢 Low  
**User Impact:** Low - Nice to have

**Missing:**
- Google Calendar sync
- Outlook calendar sync
- iCal subscription feeds
- Calendar widget embed

**Recommendation:** Phase 2 feature after recurring events

#### 2.5 Event Analytics

**Priority:** 🟢 Low  
**User Impact:** Low - Organizer feature

**Missing:**
- View count tracking (partially implemented via Metrics::Viewable)
- RSVP conversion rates
- Popular event times
- Category popularity

**Recommendation:**
```ruby
# Leverage existing Metrics::Viewable concern
# Add dashboard view for organizers
def analytics
  @view_count = @event.views_count
  @rsvp_rate = @event.rsvp_conversion_rate
  @attendance_by_status = @event.event_attendances.group(:status).count
end
```

---

## 3. Performance & Scalability

### Current Performance Profile

**Database Queries:**
- Index page: ~15-20 queries (with eager loading)
- Show page: ~10-15 queries (with preloading)
- RSVP action: 3-5 queries

### ✅ Strengths

1. **Excellent Eager Loading**
   ```ruby
   # EventPolicy::Scope
   scope.with_attached_cover_image
        .includes(:string_translations, :location, :event_hosts, 
                  categorizations: { category: [...] })
   ```

2. **Fragment Caching**
   ```erb
   <%= cache @event.cover_image do %>
     <%= cover_image_tag(@event) %>
   <% end %>
   ```

3. **Background Job Processing**
   - Geocoding runs asynchronously
   - Reminder scheduling off request cycle
   - Notification delivery in background

4. **Database Indexes**
   - Foreign keys indexed
   - `starts_at` indexed for date queries
   - Compound indexes for common queries

### ⚠️ Performance Issues

#### 3.1 N+1 Queries in Attendee Tab

**Issue:** Attendee list loads without eager loading person associations

**Impact:** High - O(n) queries for n attendees

**Current Code:**
```erb
<!-- app/views/better_together/events/_attendance_item.html.erb -->
<% @event.event_attendances.each do |attendance| %>
  <%= attendance.person.name %> <!-- N+1 HERE -->
<% end %>
```

**Fix:**
```ruby
# In EventsController#preload_event_associations!
@event.event_attendances.includes(person: [:user, :avatar_attachment]).load
```

#### 3.2 Missing Index on event_attendances

**Issue:** Queries by event_id and status not optimized

**Impact:** Medium - Slow RSVP count queries

**Recommendation:**
```ruby
# Migration
add_index :better_together_event_attendances, [:event_id, :status]
add_index :better_together_event_attendances, [:person_id, :event_id], unique: true
```

#### 3.3 Geocoding Job Synchronous in Some Paths

**Issue:** `should_geocode?` check happens on save, delays response

**Impact:** Low - Only affects events with address changes

**Recommendation:**
```ruby
# Move check to job
after_commit :queue_geocoding_check, if: :address_changed?

def queue_geocoding_check
  BetterTogether::Geography::GeocodingCheckJob.perform_later(id)
end
```

#### 3.4 No Caching for Event Lists

**Issue:** Index page recalculates queries on every request

**Impact:** Medium - Repeated database hits

**Recommendation:**
```ruby
# Add Russian Doll caching
<% cache ['events-index', @upcoming_events.maximum(:updated_at)] do %>
  <% @upcoming_events.each do |event| %>
    <% cache event do %>
      <%= render event %>
    <% end %>
  <% end %>
<% end %>
```

#### 3.5 Invitation Token Lookup Not Cached

**Issue:** Token lookups hit database on every request

**Impact:** Low - Only affects invitation users

**Recommendation:**
```ruby
# Cache valid tokens in Redis
def find_valid_invitation(token)
  Rails.cache.fetch("event_invitation:#{token}", expires_in: 1.hour) do
    EventInvitation.pending.not_expired.find_by(token: token)
  end
end
```

### Scalability Concerns

#### Database Growth
- **Event records:** Linear growth ✅
- **Attendances:** O(events × attendees) - Monitor index performance
- **Notifications:** Archive/purge old notifications ⚠️

#### Background Job Queue
- **Reminder jobs:** Spike during popular event times
- **Recommendation:** Use Sidekiq rate limiting

```ruby
class EventReminderJob
  sidekiq_options queue: :reminders, throttle: { threshold: 100, period: 1.minute }
end
```

---

## 4. Accessibility & UI/UX

### ✅ Strengths

1. **Semantic HTML**
   ```erb
   <article class="event-card" role="article">
     <h2><%= event.name %></h2>
     <time datetime="<%= event.starts_at.iso8601 %>">...</time>
   </article>
   ```

2. **ARIA Labels Present**
   ```erb
   <%= link_to event_path(event), 
       aria: { label: "View #{event.name}" } %>
   ```

3. **Keyboard Navigation**
   - Tabs work with arrow keys (Stimulus controller)
   - Forms accessible via keyboard
   - RSVP buttons keyboard-accessible

4. **Color Contrast**
   - Bootstrap 5 defaults meet WCAG AA
   - Custom colors in config checked

5. **Form Labels**
   - All inputs have associated labels
   - Error messages properly associated
   - Required fields marked

### ⚠️ Accessibility Issues

#### 4.1 Missing Skip Links

**Issue:** No skip navigation for keyboard users

**Impact:** Low - Keyboard users must tab through nav

**Recommendation:**
```erb
<!-- app/views/layouts/better_together/application.html.erb -->
<a href="#main-content" class="skip-link">Skip to main content</a>
<main id="main-content" tabindex="-1">
  <%= yield %>
</main>
```

#### 4.2 Hover Card Not Keyboard Accessible

**Issue:** Event hover cards only work on mouse hover

**Impact:** Medium - Keyboard/screen reader users miss previews

**Current:**
```javascript
setupHoverEvents() {
  this.element.addEventListener('mouseenter', ...)
  this.element.addEventListener('mouseleave', ...)
}
```

**Recommendation:**
```javascript
setupAccessibility() {
  // Add keyboard trigger
  this.element.addEventListener('focus', this.show.bind(this))
  this.element.addEventListener('blur', this.hide.bind(this))
  
  // Add ARIA live region for screen readers
  this.element.setAttribute('aria-describedby', 'event-preview')
}
```

#### 4.3 Date Picker Accessibility

**Issue:** Custom datetime controller may not announce changes

**Impact:** Medium - Screen reader users may miss feedback

**Recommendation:**
```javascript
updateEndTime() {
  // ... existing logic
  
  // Announce change to screen readers
  this.announceChange(`End time updated to ${formattedTime}`)
}

announceChange(message) {
  const liveRegion = document.getElementById('datetime-announcer')
  liveRegion.textContent = message
}
```

```erb
<!-- Add to form -->
<div id="datetime-announcer" class="sr-only" role="status" aria-live="polite"></div>
```

#### 4.4 RSVP Button States Not Clear

**Issue:** Active RSVP state only shown by color

**Impact:** Low - Color-blind users may not see status

**Recommendation:**
```erb
<%= button_to rsvp_going_event_path(@event), 
    class: "btn btn-primary #{@current_attendance&.status == 'going' ? 'active' : ''}" do %>
  <i class="fas fa-check me-2" aria-hidden="true"></i>
  <%= t('better_together.events.rsvp_going') %>
  <% if @current_attendance&.status == 'going' %>
    <span class="visually-hidden">(Currently selected)</span>
  <% end %>
<% end %>
```

### UI/UX Enhancements

#### 4.5 No Empty States for Attendees

**Issue:** Empty attendee list shows nothing

**Recommendation:**
```erb
<% if @event.event_attendances.none? %>
  <div class="text-center py-5">
    <i class="fas fa-users fa-3x text-muted mb-3"></i>
    <p class="text-muted">No RSVPs yet. Be the first!</p>
  </div>
<% end %>
```

#### 4.6 Missing Loading States

**Issue:** RSVP button clicks have no feedback before redirect

**Recommendation:**
```erb
<%= button_to rsvp_going_event_path(@event), 
    data: { 
      turbo_submits_with: "Saving RSVP...",
      disable_with: "Saving..."
    } do %>
  ...
<% end %>
```

#### 4.7 No Confirmation for Destructive Actions

**Issue:** Delete event has confirm but other actions don't

**Recommendation:**
```erb
<%= button_to rsvp_cancel_event_path(@event), 
    method: :delete,
    form: { data: { turbo_confirm: "Cancel your RSVP?" } } %>
```

---

## 5. Security & Permissions

### ✅ Strengths

1. **Comprehensive Authorization**
   - Pundit policies on all actions
   - Policy scopes filter collections
   - Authorization checked in controllers

2. **Strong Parameters**
   - `permitted_attributes` method on models
   - Nested attributes properly filtered
   - No mass assignment vulnerabilities

3. **Safe Dynamic Class Resolution**
   - `event_host_class` uses allow-list
   - `HostsEvents.included_in_models` prevents reflection attacks
   - No use of `constantize` on user input

4. **CSRF Protection**
   - Rails CSRF tokens on all forms
   - Token verification on mutations

5. **SQL Injection Prevention**
   - Arel queries throughout
   - No string interpolation in queries
   - Parameterized queries only

6. **XSS Prevention**
   - Auto-escaping enabled
   - Action Text sanitization
   - Safe HTML rendering

### ⚠️ Security Issues

#### 5.1 Missing Rate Limiting on RSVP Actions

**Issue:** Users can spam RSVP endpoints

**Impact:** Medium - Could overwhelm database/jobs

**Recommendation:**
```ruby
class EventsController
  before_action :check_rsvp_rate_limit, only: [:rsvp_interested, :rsvp_going]
  
  def check_rsvp_rate_limit
    limiter = Rack::Attack.throttle(
      "rsvp/person/#{current_person.id}",
      limit: 10, period: 1.minute
    )
  end
end
```

Or use Redis-backed throttling:
```ruby
# In controller
def rsvp_update(status)
  unless rate_limit_rsvp
    redirect_to @event, alert: "Too many RSVP attempts. Please wait."
    return
  end
  # ... existing logic
end

def rate_limit_rsvp
  key = "rsvp:#{current_person.id}:#{Time.current.to_i / 60}"
  count = Rails.cache.increment(key, 1, expires_in: 1.minute)
  count <= 10
end
```

#### 5.2 Invitation Token Session Not Secure

**Issue:** Token stored in plain session without encryption

**Impact:** Low - Session hijacking could expose tokens

**Current:**
```ruby
session[:event_invitation_token] = invitation.token
```

**Recommendation:**
```ruby
# Use encrypted credentials
encrypted_token = ActiveSupport::MessageEncryptor.new(
  Rails.application.credentials.secret_key_base[0..31]
).encrypt_and_sign(invitation.token)
session[:event_invitation_token] = encrypted_token
```

#### 5.3 No Authorization Log for Policy Checks

**Issue:** Failed authorization attempts not logged

**Impact:** Low - Hard to detect attack patterns

**Recommendation:**
```ruby
# In ApplicationPolicy
def authorize!
  unless authorized?
    Rails.logger.warn(
      "Authorization failed: #{user&.email} attempted #{action} on #{record.class}"
    )
    raise Pundit::NotAuthorizedError
  end
end
```

#### 5.4 Missing Content Security Policy Headers

**Issue:** No CSP headers to prevent XSS

**Impact:** Medium - Defense in depth missing

**Recommendation:**
```ruby
# config/initializers/content_security_policy.rb
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.img_src :self, :data, :https
  policy.script_src :self, :unsafe_inline
  policy.style_src :self, :unsafe_inline
end
```

#### 5.5 Event Invitation Token Timing Attack

**Issue:** Token comparison vulnerable to timing attacks

**Impact:** Low - Requires sophisticated attacker

**Current:**
```ruby
invitation = EventInvitation.find_by(token: token)
```

**Recommendation:**
```ruby
# Use secure comparison
invitation = EventInvitation.find_by(token: token)
return nil unless invitation
return nil unless ActiveSupport::SecurityUtils.secure_compare(
  invitation.token,
  token
)
invitation
```

---

## 6. Internationalization

### ✅ Strengths

1. **Comprehensive i18n Coverage**
   - All user-facing strings use `t()`
   - Model attributes translated (Mobility)
   - Email templates localized

2. **Multiple Locale Support**
   - EN, ES, FR, UK translations
   - Locale switching in routes
   - Session-based locale persistence

3. **Rich Text Translation**
   - Action Text fields translatable
   - Description in multiple languages

4. **Date/Time Localization**
   - `l()` helper used consistently
   - Time zones handled properly

### ⚠️ i18n Issues

#### 6.1 Missing Translation Keys

**Issue:** Some fallback default strings in views

**Current:**
```erb
<%= t('better_together.events.rsvp_going', default: 'Going') %>
```

**Recommendation:** Add all keys to locale files

```yaml
# config/locales/en.yml
en:
  better_together:
    events:
      rsvp_going: "Going"
      rsvp_interested: "Interested"
      rsvp_cancel: "Cancel RSVP"
```

**Action:** Run `i18n-tasks` to find missing keys

```bash
bin/dc-run i18n-tasks missing
bin/dc-run i18n-tasks add-missing
```

#### 6.2 Inconsistent i18n Namespace

**Issue:** Some translations under `globals.` some under `better_together.events.`

**Recommendation:** Standardize namespace structure

```yaml
# Preferred structure
en:
  better_together:
    events:
      index:
        title: "Events"
        no_events: "No events yet"
      show:
        add_to_calendar: "Add to calendar"
      form:
        start_time: "Start time"
```

#### 6.3 Pluralization Not Used

**Issue:** Hardcoded singular/plural forms

**Current:**
```erb
<%= t('better_together.events.attendee_count', count: @count) %>
<!-- Always shows "attendee" even for multiple -->
```

**Recommendation:**
```yaml
en:
  better_together:
    events:
      attendee_count:
        zero: "No attendees"
        one: "1 attendee"
        other: "%{count} attendees"
```

#### 6.4 Email Subjects Not Localized

**Issue:** Some mailer subjects in English only

**Check:**
```ruby
# app/mailers/better_together/event_mailer.rb
def reminder_email
  mail(subject: "Event reminder: #{@event.name}") # BAD
end
```

**Should be:**
```ruby
def reminder_email
  mail(subject: t('better_together.event_mailer.reminder_subject', 
                  event_name: @event.name))
end
```

---

## 7. Testing & Documentation

### Test Coverage Analysis

**Overall:** Good coverage with room for improvement

#### Model Tests
- ✅ Event model: Comprehensive (56 examples)
- ✅ EventAttendance: Good coverage with draft validation
- ✅ Scopes tested (upcoming, past, draft, scheduled)
- ⚠️ Missing: Geocoding integration tests
- ⚠️ Missing: Notification trigger tests

#### Controller/Request Tests
- ✅ CRUD operations covered
- ✅ RSVP actions tested
- ✅ Invitation token flow tested
- ⚠️ Missing: Error handling edge cases
- ⚠️ Missing: Rate limiting tests

#### Policy Tests
- ✅ Authorization matrix covered
- ✅ Draft event restrictions tested
- ⚠️ Missing: Invitation token edge cases
- ⚠️ Missing: Host authorization scenarios

#### Integration Tests
- ✅ Feature specs for datetime partial
- ⚠️ Missing: Full user journey specs
- ⚠️ Missing: Calendar integration tests
- ⚠️ Missing: Email delivery tests

#### JavaScript Tests
- ❌ Missing: No tests for Stimulus controllers
- ❌ Missing: No tests for hover card behavior
- ❌ Missing: No tests for datetime sync

### Documentation Quality

#### ✅ Excellent Documentation
- `docs/developers/systems/events_system.md` (458 lines)
- `docs/developers/systems/event_invitations_and_attendance.md` (comprehensive)
- `docs/developers/systems/event_attendance_assessment.md` (improvement tracking)
- Mermaid diagrams (flow, architecture, technical)

#### ⚠️ Documentation Gaps

1. **API Documentation Missing**
   - No Swagger/OpenAPI spec
   - No API endpoint documentation for JSON responses

2. **Inline Code Comments Sparse**
   - Complex methods lack explanation
   - Policy logic not documented
   - Concern usage not explained

3. **Example Code Limited**
   - No example implementations for extensions
   - No cookbook for common customizations

4. **Performance Tuning Guide Missing**
   - No guidance on scaling
   - No database optimization tips
   - No caching strategy doc

---

## 8. Prioritized Recommendations

### 🔴 High Priority (Security & Performance)

#### P1: Add Rate Limiting to RSVP Actions
**Impact:** Prevents abuse, protects database  
**Effort:** 2 hours  
**Dependencies:** Redis (already in use)

#### P2: Fix N+1 Queries in Attendee Tab
**Impact:** Improves show page performance  
**Effort:** 1 hour  
**Dependencies:** None

#### P3: Add Missing Database Indexes
**Impact:** Faster RSVP queries, better scalability  
**Effort:** 1 hour  
**Dependencies:** None

#### P4: Implement Event Filtering
**Impact:** Major UX improvement for event discovery  
**Effort:** 8 hours  
**Dependencies:** None

#### P5: Add JavaScript Tests
**Impact:** Prevents regressions in interactive features  
**Effort:** 6 hours  
**Dependencies:** Jest or similar

### 🟡 Medium Priority (Features & UX)

#### P6: Attendee Management UI
**Impact:** Organizer productivity  
**Effort:** 12 hours  
**Dependencies:** None

#### P7: Improve Keyboard Accessibility
**Impact:** Accessibility compliance (WCAG AAA)  
**Effort:** 4 hours  
**Dependencies:** None

#### P8: Add Empty States & Loading Feedback
**Impact:** Better UX, less user confusion  
**Effort:** 3 hours  
**Dependencies:** None

#### P9: Extract RSVP Controller
**Impact:** Better code organization  
**Effort:** 4 hours  
**Dependencies:** None

#### P10: Add Calendar List Caching
**Impact:** Faster page loads  
**Effort:** 3 hours  
**Dependencies:** Redis

### 🟢 Low Priority (Nice to Have)

#### P11: Implement Recurring Events
**Impact:** Major feature addition  
**Effort:** 40 hours  
**Dependencies:** Careful design required

#### P12: Add Event Analytics Dashboard
**Impact:** Organizer insights  
**Effort:** 16 hours  
**Dependencies:** None

#### P13: Google Calendar Integration
**Impact:** Convenience feature  
**Effort:** 20 hours  
**Dependencies:** Google API credentials

#### P14: Add API Documentation
**Impact:** Developer experience  
**Effort:** 8 hours  
**Dependencies:** None

#### P15: Consolidate i18n Namespaces
**Impact:** Code clarity  
**Effort:** 4 hours  
**Dependencies:** None

---

## 9. Implementation Roadmap

### Sprint 1: Performance & Security (1 week)

**Goal:** Fix critical performance and security issues

**Tasks:**
1. ✅ Add rate limiting to RSVP actions (P1)
2. ✅ Fix N+1 queries in attendee tab (P2)
3. ✅ Add missing database indexes (P3)
4. ✅ Implement invitation token encryption (from 5.2)
5. ✅ Add authorization logging (from 5.3)

**Deliverables:**
- Rate limiting implemented and tested
- Zero N+1 queries on show page
- Database indexes added and measured
- Security improvements deployed

**Success Metrics:**
- Show page queries < 10
- RSVP rate limit working (10/min)
- No new Brakeman warnings

---

### Sprint 2: Event Discovery (1 week)

**Goal:** Improve event discoverability with filtering

**Tasks:**
1. ✅ Design filter UI mockups (P4)
2. ✅ Implement EventFilterService
3. ✅ Add date range filters
4. ✅ Add category filters
5. ✅ Add keyword search
6. ✅ Add filter tests

**Deliverables:**
- Working event filters on index page
- URL-based filter state
- Tests covering all filter combinations

**Success Metrics:**
- Users can filter by date, category, location
- Filter state persists in URL
- Test coverage > 90%

---

### Sprint 3: Accessibility & UX (1 week)

**Goal:** Improve accessibility and user experience

**Tasks:**
1. ✅ Add keyboard accessibility to hover cards (P7)
2. ✅ Improve RSVP button states (from 4.4)
3. ✅ Add empty states (P8)
4. ✅ Add loading feedback (from 4.6)
5. ✅ Add skip links (from 4.1)
6. ✅ Add ARIA live regions for datetime updates (from 4.3)

**Deliverables:**
- WCAG AAA compliance
- Improved keyboard navigation
- Better user feedback

**Success Metrics:**
- Passes axe DevTools audit
- All interactive elements keyboard-accessible
- Screen reader tested

---

### Sprint 4: Organizer Tools (1.5 weeks)

**Goal:** Improve event management for organizers

**Tasks:**
1. ✅ Implement attendee CSV export (P6)
2. ✅ Add check-in functionality (P6)
3. ✅ Add capacity management (P6)
4. ✅ Add waitlist support (P6)
5. ✅ Improve invitation management UI

**Deliverables:**
- Attendee export working
- Check-in interface
- Capacity enforcement
- Waitlist functionality

**Success Metrics:**
- Organizers can export attendee lists
- Events can have capacity limits
- Waitlist automatically promotes

---

### Sprint 5: Code Quality (1 week)

**Goal:** Improve maintainability and testing

**Tasks:**
1. ✅ Extract RSVP controller (P9)
2. ✅ Add JavaScript tests (P5)
3. ✅ Consolidate preloading logic (from 1.3)
4. ✅ Add inline documentation
5. ✅ Consolidate i18n keys (P15)

**Deliverables:**
- Better code organization
- JavaScript test suite
- Improved documentation

**Success Metrics:**
- Controller < 200 lines
- JS test coverage > 80%
- All i18n keys in proper namespace

---

## Post-Sprint: Future Enhancements

### Phase 2: Advanced Features (4-6 weeks)

**Large Features:**
1. 🚀 Recurring Events (P11) - 2 weeks
2. 🚀 Event Analytics Dashboard (P12) - 1 week
3. 🚀 Calendar API Integration (P13) - 1.5 weeks
4. 🚀 Advanced Location Features - 1 week
   - Map view of events
   - Proximity search
   - Venue suggestions

### Phase 3: Platform Scaling (2-3 weeks)

**Infrastructure:**
1. Implement Redis caching strategy (P10)
2. Add CDN for event images
3. Optimize notification delivery
4. Add event archival system
5. Implement read replicas for queries

---

## Appendix A: File Inventory

### Models (6 files)
- `app/models/better_together/event.rb` (322 lines)
- `app/models/better_together/event_attendance.rb` (64 lines)
- `app/models/better_together/event_host.rb`
- `app/models/better_together/event_invitation.rb`
- `app/models/better_together/event_category.rb`
- `app/models/better_together/calendar_entry.rb`

### Controllers (2 files)
- `app/controllers/better_together/events_controller.rb` (341 lines)
- `app/controllers/better_together/invitations_controller.rb` (unified polymorphic controller for all invitation types)

### Views (14 files)
- `app/views/better_together/events/index.html.erb`
- `app/views/better_together/events/show.html.erb`
- `app/views/better_together/events/edit.html.erb`
- `app/views/better_together/events/new.html.erb`
- `app/views/better_together/events/_form.html.erb`
- `app/views/better_together/events/_event.html.erb`
- `app/views/better_together/events/_event_hosts.html.erb`
- `app/views/better_together/events/_attendance_item.html.erb`
- `app/views/better_together/events/_invitations_panel.html.erb`
- `app/views/better_together/events/_invitations_table.html.erb`
- `app/views/better_together/events/_invitation_row.html.erb`
- `app/views/better_together/events/_invitation_review.html.erb`
- `app/views/better_together/events/_event_datetime_fields.html.erb`
- `app/views/better_together/events/_none.html.erb`

### JavaScript (2 files)
- `app/javascript/controllers/better_together/event_datetime_controller.js` (128 lines)
- `app/javascript/controllers/better_together/event_hover_card_controller.js` (272 lines)

### Policies (2 files)
- `app/policies/better_together/event_policy.rb` (158 lines)
- `app/policies/better_together/event_attendance_policy.rb`

### Jobs (3 files)
- `app/jobs/better_together/event_reminder_job.rb`
- `app/jobs/better_together/event_reminder_scheduler_job.rb`
- `app/jobs/better_together/event_reminder_scan_job.rb`

### Notifiers (3 files)
- `app/notifiers/better_together/event_invitation_notifier.rb`
- `app/notifiers/better_together/event_reminder_notifier.rb`
- `app/notifiers/better_together/event_update_notifier.rb`

### Mailers (2 files)
- `app/mailers/better_together/event_mailer.rb`
- `app/mailers/better_together/event_invitations_mailer.rb`

### Tests
- Model specs: 5+ files
- Request specs: 2 files
- Policy specs: 2+ files
- Job specs: 3 files
- **Total test coverage:** Good but incomplete

---

## Appendix B: Dependencies

### Ruby Gems
- `rails` ~> 8.0.2
- `pundit-resources` (authorization)
- `noticed` (notifications)
- `mobility` (translations)
- `sidekiq` (background jobs)
- `pg` (PostgreSQL)
- `redis` (caching/jobs)
- `active_storage` (file uploads)
- `action_text` (rich text)

### JavaScript
- `@hotwired/stimulus`
- `@hotwired/turbo-rails`
- Bootstrap 5.3 (no npm, importmap)

### External Services
- **Required:** PostgreSQL + PostGIS
- **Required:** Redis
- **Optional:** Geocoding API (for addresses)
- **Optional:** Email service (SMTP)

---

## Appendix C: Key Metrics

### Code Metrics
- **Total Lines of Code:** ~3,000 (events feature)
- **Controller Complexity:** Medium (341 lines main controller)
- **Test Coverage:** ~85% (estimated)
- **Rubocop Offenses:** Minimal (mostly Metrics cops disabled intentionally)

### Performance Baselines
- **Index Page:** ~15-20 queries, ~150ms
- **Show Page:** ~10-15 queries, ~100ms
- **RSVP Action:** ~3-5 queries, ~50ms
- **Background Jobs:** Processing ~5/sec capacity

### User Metrics (Estimated)
- **Events Created:** N/A (new deployment)
- **RSVPs:** N/A
- **Invitations Sent:** N/A
- **Popular Event Times:** N/A

---

## Conclusion

The Events feature is **production-ready** with a solid foundation. The identified improvements are primarily **enhancements rather than fixes**, focusing on:

1. **Performance optimization** (caching, indexes)
2. **Feature completeness** (filtering, attendee management)
3. **Accessibility** (keyboard nav, ARIA)
4. **Code quality** (testing, organization)

**Recommended Action:** Proceed with Sprint 1 (Performance & Security) immediately, then prioritize based on user feedback and usage patterns.

---

**Document Version:** 1.0  
**Last Updated:** November 5, 2025  
**Next Review:** After Sprint 2 completion
