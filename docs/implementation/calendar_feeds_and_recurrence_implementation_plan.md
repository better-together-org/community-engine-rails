# Calendar Feeds and Recurrence Implementation Plan

**Status**: In Progress  
**Created**: 2026-01-23  
**Priority**: High  
**Stakeholder Impact**: End Users, Community Organizers, Platform Organizers

## Overview

Extend the Better Together calendar system to support multi-event feeds, recurring events with RRULE, attendee/organizer management, exportable reminders (VALARM), calendar subscriptions, and alternative export formats.

## Current State Assessment

### Existing Capabilities
- ✅ Single event ICS export with timezone support
- ✅ Personal and community calendars
- ✅ RSVP integration creating calendar entries
- ✅ Event reminder notifications (24h, 1h, start-time)
- ✅ Custom ICS generation services (Generator, EventBuilder, TimezoneBuilder, Formatter)
- ✅ EventAttendance tracking (going/interested status)

### Critical Gaps
- ❌ No recurring events support (RRULE)
- ❌ No calendar subscription URLs
- ❌ No multi-event calendar feeds
- ❌ No ATTENDEE/ORGANIZER fields in ICS exports
- ❌ No VALARM blocks in ICS exports
- ❌ No alternative export formats
- ❌ CalendarEntry temporal data staleness (not synced with Event updates)

### Technical Debt
- Custom ICS generation instead of standard library
- Denormalized temporal data in CalendarEntry without sync
- No caching for calendar feeds (performance concern)

## Implementation Strategy

### Approach
- **Phase-based delivery**: Implement in logical dependency order
- **TDD methodology**: Write failing tests before implementation
- **Stakeholder-driven**: Prioritize by impact across user types
- **Incremental refactoring**: Replace custom ICS with icalendar gem
- **Backward compatibility**: Maintain existing single-event exports

### Technology Decisions

**Dependencies to Add:**
```ruby
# better_together.gemspec
spec.add_dependency 'icalendar', '~> 2.10'  # Standard ICS library
spec.add_dependency 'ice_cube', '~> 0.16'    # Recurring events
```

**Storage Strategy:**
- Store RRULE as serialized text (ice_cube YAML)
- On-demand expansion for queries (no pre-generated occurrences)
- Exception dates stored as array column

**Security Model:**
- Per-calendar UUID subscription tokens
- Token validation on feed endpoints
- Public/private calendar privacy enforcement

## Phase 1: Foundation & Multi-Event Feeds

### 1.1 Add Dependencies
**Files**: `better_together.gemspec`

```ruby
spec.add_dependency 'icalendar', '~> 2.10'
spec.add_dependency 'ice_cube', '~> 0.16'
```

**Tests**: Verify gem loading in spec_helper

### 1.2 Add Calendar Subscription Token
**Migration**: `AddSubscriptionTokenToCalendars`

```ruby
add_column :better_together_calendars, :subscription_token, :string
add_index :better_together_calendars, :subscription_token, unique: true
```

**Model Changes**: `app/models/better_together/calendar.rb`
- Add `before_create :generate_subscription_token`
- Add `regenerate_subscription_token!` method
- Validate uniqueness of subscription_token

**Tests**: `spec/models/better_together/calendar_spec.rb`
- Token generated on creation
- Token is unique
- Regeneration creates new token

### 1.3 Refactor ICS Services to Use Icalendar Gem
**Files to Modify**:
- `app/services/better_together/ics/generator.rb`
- `app/services/better_together/ics/event_builder.rb`
- `app/services/better_together/ics/timezone_builder.rb`

**Changes**:
- Replace custom ICS string building with `Icalendar::Calendar`
- Use `Icalendar::Event` instead of manual VEVENT construction
- Leverage `TZInfo::Timezone` for VTIMEZONE generation
- Maintain backward compatibility with existing `Event#to_ics`

**Tests**: `spec/services/better_together/ics/*_spec.rb`
- Existing tests should continue passing
- Output format validation
- Timezone handling verification

### 1.4 Extend Generator for Multiple Events
**File**: `app/services/better_together/ics/generator.rb`

**Changes**:
```ruby
# Support both single event and collection
def initialize(events)
  @events = Array.wrap(events)
end

def generate
  calendar = Icalendar::Calendar.new
  calendar.prodid = '-//Better Together//Community Engine//EN'
  
  @events.each do |event|
    calendar.event do |e|
      EventBuilder.new(event).build(e)
    end
  end
  
  calendar.to_ical
end
```

**Tests**: `spec/services/better_together/ics/generator_spec.rb`
- Single event generation (backward compatibility)
- Multiple events generation
- Empty collection handling
- Proper VCALENDAR wrapper

### 1.5 Calendar Feed Controller & Routes
**Route**: `config/routes.rb`

```ruby
resources :calendars do
  member do
    get 'feed', defaults: { format: :ics }
  end
end
```

**Controller**: `app/controllers/better_together/calendars_controller.rb`

```ruby
def feed
  @calendar = Calendar.find(params[:id])
  authorize_subscription_token!
  
  @events = @calendar.events.scheduled.order(:starts_at)
  
  respond_to do |format|
    format.ics do
      ics_content = Ics::Generator.new(@events).generate
      send_data ics_content,
                type: 'text/calendar; charset=UTF-8',
                disposition: 'inline',
                filename: "#{@calendar.slug}.ics"
    end
  end
end

private

def authorize_subscription_token!
  token = params[:token]
  return if @calendar.subscription_token == token
  return if @calendar.privacy_public? && current_person.present?
  
  head :unauthorized
end
```

**Tests**: `spec/requests/better_together/calendars_spec.rb`
- Feed with valid token returns ICS
- Feed with invalid token returns 401
- Public calendar without token (authenticated)
- Multiple events in feed
- Content-Type headers
- Cache headers

### 1.6 Fix CalendarEntry Temporal Data Sync
**File**: `app/models/better_together/event.rb`

```ruby
after_update :sync_calendar_entry_times, if: :saved_change_to_starts_at_or_ends_at?

private

def sync_calendar_entry_times
  calendar_entries.update_all(
    starts_at: starts_at,
    ends_at: ends_at,
    duration_minutes: duration_minutes
  )
end

def saved_change_to_starts_at_or_ends_at?
  saved_change_to_starts_at? || saved_change_to_ends_at?
end
```

**Tests**: `spec/models/better_together/event_spec.rb`
- Updating event times updates calendar entries
- Multiple calendar entries all updated
- Only updates when temporal fields change

## Phase 2: Recurring Events (RRULE)

### 2.1 Add Recurrence Fields to Events
**Migration**: `AddRecurrenceFieldsToEvents`

```ruby
add_column :better_together_events, :recurrence_rule, :text
add_column :better_together_events, :recurrence_exception_dates, :date, array: true, default: []
add_column :better_together_events, :parent_event_id, :uuid
add_column :better_together_events, :is_recurring, :boolean, default: false

add_index :better_together_events, :parent_event_id
add_index :better_together_events, :is_recurring
```

**Tests**: Schema verification

### 2.2 Create RecurringEvent Concern
**File**: `app/models/concerns/better_together/recurring_event.rb`

```ruby
module BetterTogether
  module RecurringEvent
    extend ActiveSupport::Concern
    
    included do
      serialize :recurrence_rule, coder: JSON
      
      validates :recurrence_rule, presence: true, if: :is_recurring?
      validate :validate_recurrence_rule, if: :is_recurring?
    end
    
    def schedule
      return nil unless is_recurring? && recurrence_rule.present?
      
      @schedule ||= IceCube::Schedule.from_yaml(recurrence_rule)
    end
    
    def occurrences_between(start_date, end_date)
      return [self] unless is_recurring?
      
      schedule.occurrences_between(start_date, end_date).map do |occurrence_time|
        EventOccurrence.new(self, occurrence_time)
      end
    end
    
    def next_occurrence(after: Time.current)
      return nil unless is_recurring?
      
      schedule.next_occurrence(after)
    end
    
    private
    
    def validate_recurrence_rule
      IceCube::Schedule.from_yaml(recurrence_rule)
    rescue => e
      errors.add(:recurrence_rule, "is invalid: #{e.message}")
    end
  end
end
```

**Tests**: `spec/models/concerns/better_together/recurring_event_spec.rb`
- Schedule creation from rule
- Occurrence expansion
- Exception dates
- Next occurrence calculation
- Validation of rule format

### 2.3 Create EventOccurrence Value Object
**File**: `app/models/better_together/event_occurrence.rb`

```ruby
module BetterTogether
  class EventOccurrence
    attr_reader :parent_event, :starts_at
    
    def initialize(parent_event, starts_at)
      @parent_event = parent_event
      @starts_at = starts_at
    end
    
    def ends_at
      starts_at + parent_event.duration_minutes.minutes
    end
    
    def name
      parent_event.name
    end
    
    def description
      parent_event.description
    end
    
    # Delegate other attributes to parent
    delegate :timezone, :location, :creator, :privacy, to: :parent_event
    
    def recurring?
      true
    end
    
    def occurrence_date
      starts_at.to_date
    end
  end
end
```

**Tests**: `spec/models/better_together/event_occurrence_spec.rb`
- Attribute delegation
- Time calculation
- Equality comparison

### 2.4 Add RRULE Support to EventBuilder
**File**: `app/services/better_together/ics/event_builder.rb`

```ruby
def build(icalendar_event)
  # ... existing fields ...
  
  if event.is_recurring? && event.schedule
    icalendar_event.rrule = event.schedule.to_ical
    
    if event.recurrence_exception_dates.any?
      event.recurrence_exception_dates.each do |exdate|
        icalendar_event.exdate = exdate
      end
    end
  end
  
  icalendar_event
end
```

**Tests**: `spec/services/better_together/ics/event_builder_spec.rb`
- RRULE exported for recurring events
- EXDATE exported for exception dates
- Non-recurring events have no RRULE

### 2.5 Recurrence Rule Form Helpers
**Helper**: `app/helpers/better_together/recurrence_helper.rb`

```ruby
module BetterTogether
  module RecurrenceHelper
    FREQUENCIES = {
      daily: 'Daily',
      weekly: 'Weekly',
      monthly: 'Monthly',
      yearly: 'Yearly'
    }.freeze
    
    def recurrence_frequency_options
      FREQUENCIES.map { |k, v| [v, k] }
    end
    
    def recurrence_end_type_options
      [
        ['Never', 'never'],
        ['On date', 'until'],
        ['After occurrences', 'count']
      ]
    end
    
    def weekday_checkboxes(form)
      Date::DAYNAMES.map.with_index do |day, index|
        content_tag(:div, class: 'form-check form-check-inline') do
          form.check_box(:weekdays, { multiple: true, class: 'form-check-input' }, 
                        index, nil) +
          form.label(:weekdays, day, class: 'form-check-label', value: index)
        end
      end.join.html_safe
    end
  end
end
```

**Tests**: `spec/helpers/better_together/recurrence_helper_spec.rb`
- Frequency options
- End type options
- Weekday checkboxes generation

### 2.6 Recurrence Form Stimulus Controller
**File**: `app/javascript/controllers/better_together/recurrence_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frequency", "interval", "endType", "untilDate", "count", "weekdays", "preview"]
  
  connect() {
    this.updateVisibility()
    this.updatePreview()
  }
  
  updateVisibility() {
    const frequency = this.frequencyTarget.value
    const endType = this.endTypeTarget.value
    
    // Show/hide weekday selector for weekly frequency
    if (this.hasWeekdaysTarget) {
      this.weekdaysTarget.style.display = frequency === 'weekly' ? 'block' : 'none'
    }
    
    // Show/hide end type fields
    if (this.hasUntilDateTarget) {
      this.untilDateTarget.style.display = endType === 'until' ? 'block' : 'none'
    }
    if (this.hasCountTarget) {
      this.countTarget.style.display = endType === 'count' ? 'block' : 'none'
    }
  }
  
  updatePreview() {
    // Fetch preview from server
    const params = new URLSearchParams({
      frequency: this.frequencyTarget.value,
      interval: this.intervalTarget.value,
      end_type: this.endTypeTarget.value
    })
    
    fetch(`/events/recurrence_preview?${params}`)
      .then(response => response.text())
      .then(html => {
        if (this.hasPreviewTarget) {
          this.previewTarget.innerHTML = html
        }
      })
  }
}
```

**Tests**: System tests for recurrence form interaction

## Phase 3: Attendee Management

### 3.1 Add ATTENDEE and ORGANIZER to EventBuilder
**File**: `app/services/better_together/ics/event_builder.rb`

```ruby
def build(icalendar_event)
  # ... existing fields ...
  
  # Add organizer
  if event.creator
    icalendar_event.organizer = Icalendar::Values::CalAddress.new(
      "mailto:#{event.creator.email}",
      cn: event.creator.name
    )
  end
  
  # Add attendees
  event.event_attendances.includes(:person).each do |attendance|
    partstat = attendance.status == 'going' ? 'ACCEPTED' : 'TENTATIVE'
    
    icalendar_event.append_attendee(
      Icalendar::Values::CalAddress.new(
        "mailto:#{attendance.person.email}",
        cn: attendance.person.name,
        partstat: partstat,
        rsvp: 'TRUE'
      )
    )
  end
  
  icalendar_event
end
```

**Tests**: `spec/services/better_together/ics/event_builder_spec.rb`
- ORGANIZER field exported
- ATTENDEE fields for each attendance
- PARTSTAT mapping (going→ACCEPTED, interested→TENTATIVE)
- Email and name included

## Phase 4: Event Reminders (VALARM)

### 4.1 Add VALARM Support to EventBuilder
**File**: `app/services/better_together/ics/event_builder.rb`

```ruby
def build(icalendar_event)
  # ... existing fields ...
  
  # Add reminders based on notification preferences
  add_valarm_components(icalendar_event)
  
  icalendar_event
end

private

def add_valarm_components(icalendar_event)
  # 24 hour reminder
  icalendar_event.alarm do |a|
    a.action = 'DISPLAY'
    a.trigger = '-PT24H'
    a.description = "Reminder: #{event.name} starts in 24 hours"
  end
  
  # 1 hour reminder
  icalendar_event.alarm do |a|
    a.action = 'DISPLAY'
    a.trigger = '-PT1H'
    a.description = "Reminder: #{event.name} starts in 1 hour"
  end
  
  # At start reminder
  icalendar_event.alarm do |a|
    a.action = 'DISPLAY'
    a.trigger = 'PT0M'
    a.description = "#{event.name} is starting now"
  end
end
```

**Tests**: `spec/services/better_together/ics/event_builder_spec.rb`
- VALARM components exported
- Correct trigger times
- Display action set

## Phase 5: Alternative Export Formats

### 5.1 Create Google Calendar JSON Exporter
**File**: `app/services/better_together/calendar_export/google_calendar_json.rb`

```ruby
module BetterTogether
  module CalendarExport
    class GoogleCalendarJson
      def initialize(events)
        @events = Array.wrap(events)
      end
      
      def generate
        {
          kind: 'calendar#events',
          summary: 'Better Together Events',
          items: @events.map { |event| event_to_json(event) }
        }.to_json
      end
      
      private
      
      def event_to_json(event)
        {
          kind: 'calendar#event',
          id: event.id,
          summary: event.name,
          description: event.description&.to_plain_text,
          start: {
            dateTime: event.starts_at.iso8601,
            timeZone: event.timezone || 'UTC'
          },
          end: {
            dateTime: event.ends_at.iso8601,
            timeZone: event.timezone || 'UTC'
          },
          location: event.location&.full_address,
          creator: creator_json(event.creator),
          attendees: attendees_json(event)
        }
      end
      
      def creator_json(creator)
        return nil unless creator
        
        {
          email: creator.email,
          displayName: creator.name
        }
      end
      
      def attendees_json(event)
        event.event_attendances.includes(:person).map do |attendance|
          {
            email: attendance.person.email,
            displayName: attendance.person.name,
            responseStatus: attendance.status == 'going' ? 'accepted' : 'tentative'
          }
        end
      end
    end
  end
end
```

**Tests**: `spec/services/better_together/calendar_export/google_calendar_json_spec.rb`
- Valid JSON output
- Google Calendar API v3 schema compliance
- Event field mapping
- Attendee export

### 5.2 Add Format Support to Controllers
**File**: `app/controllers/better_together/calendars_controller.rb`

```ruby
def feed
  @calendar = Calendar.find(params[:id])
  authorize_subscription_token!
  
  @events = @calendar.events.scheduled.order(:starts_at)
  
  respond_to do |format|
    format.ics do
      ics_content = Ics::Generator.new(@events).generate
      send_data ics_content,
                type: 'text/calendar; charset=UTF-8',
                disposition: 'inline',
                filename: "#{@calendar.slug}.ics"
    end
    
    format.json do
      json_content = CalendarExport::GoogleCalendarJson.new(@events).generate
      send_data json_content,
                type: 'application/json; charset=UTF-8',
                disposition: 'inline',
                filename: "#{@calendar.slug}.json"
    end
  end
end
```

**Tests**: `spec/requests/better_together/calendars_spec.rb`
- JSON format response
- Content-Type headers
- Format negotiation

## Testing Strategy

### Unit Tests
- ✅ Model validations and associations
- ✅ Service object business logic
- ✅ Helper methods
- ✅ Value objects (EventOccurrence)
- ✅ Concerns (RecurringEvent)

### Integration Tests
- ✅ Controller actions
- ✅ ICS generation end-to-end
- ✅ Subscription token authentication
- ✅ Format negotiation

### System Tests
- ✅ Recurrence form interactions
- ✅ Calendar subscription workflow
- ✅ Event creation with recurrence

### Performance Tests
- ✅ Calendar feed generation with 100+ events
- ✅ Recurrence expansion for long series
- ✅ Cache effectiveness

## Acceptance Criteria

### End Users
- [ ] Can subscribe to community calendars in external apps
- [ ] Events display with correct timezone information
- [ ] Recurring events show as single series with repeats
- [ ] Reminders trigger in external calendar apps
- [ ] Can export events in multiple formats

### Community Organizers
- [ ] Can create recurring events via form
- [ ] Can view next 5 occurrences in event preview
- [ ] Can share calendar subscription URLs
- [ ] Calendar feeds update automatically when events change
- [ ] Attendee list exports to external calendars

### Platform Organizers
- [ ] Can monitor subscription usage
- [ ] Calendar feeds perform well with 100+ events
- [ ] Can regenerate subscription tokens for security
- [ ] All existing single-event exports continue working

## Rollout Plan

### Phase 1: Foundation (Week 1-2)
- Add gems
- Refactor to icalendar gem
- Multi-event feeds
- Subscription tokens
- Fix CalendarEntry sync

### Phase 2: Recurrence (Week 3-4)
- Database fields
- RecurringEvent concern
- EventOccurrence value object
- RRULE export
- Form helpers and UI

### Phase 3: Attendees & Reminders (Week 5)
- ATTENDEE/ORGANIZER export
- VALARM components
- Notification preference integration

### Phase 4: Alternative Formats (Week 6)
- Google Calendar JSON
- Format negotiation
- Documentation

### Phase 5: Polish & Performance (Week 7)
- Caching implementation
- Performance optimization
- Documentation updates
- Stakeholder training materials

## Risks & Mitigations

### Risk: Breaking Changes to Existing ICS Exports
**Mitigation**: Comprehensive test coverage, parallel testing, gradual rollout

### Risk: Performance Degradation with Large Calendars
**Mitigation**: Pagination, caching, performance benchmarks before release

### Risk: Recurring Event Complexity
**Mitigation**: Start with simple patterns (daily/weekly), expand gradually

### Risk: Timezone Edge Cases
**Mitigation**: Extensive DST testing, timezone validation, fallback to UTC

## Documentation Updates Required

- [ ] End User Guide: Calendar subscriptions
- [ ] Community Organizer Guide: Creating recurring events
- [ ] Platform Organizer Guide: Managing calendar feeds
- [ ] Developer Docs: ICS service architecture
- [ ] API Reference: Export format specifications
- [ ] Diagram: Calendar subscription flow
- [ ] Diagram: Recurring event expansion

## Success Metrics

- Calendar subscription adoption: >30% of active users within 3 months
- Recurring event usage: >50% of regular event creators
- External calendar sync: >70% of RSVP'd events added to personal calendars
- Feed performance: <200ms response time for 50-event feeds
- Support tickets: <5% increase from calendar feature changes

## Related Documentation

- [Calendar System Documentation](../end_users/community_participation/calendar_management.md)
- [Event System Documentation](../developers/events_system.md)
- [Timezone Handling Strategy](../development/timezone_handling_strategy.md)
- [Stakeholder Documentation](../table_of_contents.md)
