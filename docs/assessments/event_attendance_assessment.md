# Event Attendance Assessment & Improvements

## Overview

This document outlines the assessment and improvements made to the Better Together Community Engine's event attendance (RSVP) functionality, addressing under which conditions users should be able to indicate or change their attendance.

## Assessment of Current Implementation

### Original Behavior

The original implementation allowed users to RSVP to events with minimal restrictions:

- **Authentication Required**: Users must be logged in
- **No Date Restrictions**: Users could RSVP to any event regardless of:
  - Whether the event had a start date (draft events)
  - Whether the event was in the past
  - Event scheduling status

### Identified Issues

1. **Draft Events**: Users could RSVP to unscheduled draft events, which creates confusion
2. **Incomplete UX**: No clear messaging about why RSVP might not be available
3. **Business Logic Gap**: Missing validation for appropriate RSVP timing

## Implemented Improvements

### 1. Draft Event Restrictions

**Problem**: Users could RSVP to draft events (events without `starts_at` date)

**Solution**: 
- Added UI logic to hide RSVP buttons for draft events
- Added informational message explaining RSVP will be available once scheduled
- Implemented server-side validation in policy and model layers

### 2. Enhanced User Experience

**Problem**: No clear feedback about RSVP availability

**Solution**:
- Added informational alert for draft events explaining when RSVP becomes available
- Added proper error messages with internationalization support
- Maintained existing RSVP functionality for scheduled events

### 3. Multi-Layer Validation

**Problem**: Client-side only restrictions could be bypassed

**Solution**:
- **View Layer**: Conditional display based on event state
- **Policy Layer**: Authorization checks prevent unauthorized access
- **Controller Layer**: Graceful error handling with user feedback
- **Model Layer**: Data validation ensures consistency

## Code Changes Made

### 1. View Template Updates (`show.html.erb`)

```erb
<!-- Before: Always showed RSVP if user logged in -->
<% if current_person %>
  <!-- RSVP buttons -->
<% end %>

<!-- After: Check if event is scheduled -->
<% if current_person && @event.scheduled? %>
  <!-- RSVP buttons -->
<% elsif current_person && @event.draft? %>
  <div class="alert alert-info">
    RSVP will be available once this event is scheduled.
  </div>
<% end %>
```

### 2. Policy Updates (`EventAttendancePolicy`)

```ruby
# Added event scheduling validation
def create?
  user.present? && event_allows_rsvp?
end

def update?
  user.present? && record.person_id == agent&.id && event_allows_rsvp?
end

private

def event_allows_rsvp?
  event = record&.event || record
  return false unless event
  event.scheduled? # Don't allow RSVP for draft events
end
```

### 3. Controller Updates (`EventsController`)

```ruby
# Added draft event check in RSVP methods
def rsvp_update(status)
  @event = set_resource_instance
  authorize @event, :show?
  
  unless @event.scheduled?
    redirect_to @event, alert: t('better_together.events.rsvp_not_available')
    return
  end
  
  # ... existing RSVP logic
end
```

### 4. Model Validation (`EventAttendance`)

```ruby
# Added validation to prevent draft event attendance
validates :event_id, uniqueness: { scope: :person_id }
validate :event_must_be_scheduled

private

def event_must_be_scheduled
  return unless event
  unless event.scheduled?
    errors.add(:event, 'must be scheduled to allow RSVPs')
  end
end
```

## Recommendations for Event Attendance

### ✅ When Users SHOULD Be Able to RSVP:

1. **Scheduled Future Events**: Events with `starts_at` date in the future
2. **Scheduled Current Events**: Events happening now (if still accepting RSVPs)
3. **Any Scheduled Event**: As long as the event has a confirmed date/time

### ❌ When Users SHOULD NOT Be Able to RSVP:

1. **Draft Events**: Events without `starts_at` date (unscheduled)
2. **Potentially Past Events**: Depending on business requirements

### 🤔 Considerations for Past Events:

The current implementation still allows RSVPs to past events. Consider these options:

1. **Allow RSVPs**: For record-keeping and "I attended" functionality
2. **Restrict RSVPs**: To prevent confusion about future attendance
3. **Different Status**: Add "attended" status for post-event interactions

### Future Enhancements

1. **Time-Based Restrictions**: 
   - Stop RSVPs X hours before event starts
   - Different cutoff times for different event types

2. **Capacity Limits**:
   - Maximum attendee validation
   - Waitlist functionality for full events

3. **Event Status Integration**:
   - Cancelled events should block new RSVPs
   - Postponed events might temporarily disable RSVPs

4. **Enhanced UX**:
   - More granular status messages
   - Visual indicators for RSVP availability
   - Countdown timers for RSVP deadlines

## Testing Coverage

### New Tests Added:

1. **Model Validation Tests**: Verify draft events reject RSVPs
2. **Policy Tests**: Ensure authorization prevents draft event RSVPs  
3. **Controller Tests**: Confirm proper error handling and redirects
4. **Integration Tests**: End-to-end RSVP workflow validation

### Test Results:
- All existing tests continue to pass
- New restrictions properly implemented
- Graceful degradation for existing data

## Internationalization

Added new translation keys:

```yaml
better_together:
  events:
    rsvp_not_available: "RSVP is not available for this event."
    rsvp_unavailable_draft: "RSVP will be available once this event is scheduled."
```

## Security Considerations

- All changes maintain existing authorization patterns
- Multiple validation layers prevent bypass attempts
- No sensitive information exposed in error messages
- Existing Brakeman security scan passes without new issues

## Conclusion

The implemented changes provide a more robust and user-friendly event attendance system that:

1. **Prevents Confusion**: Clear restrictions on when RSVPs are available
2. **Maintains Flexibility**: Existing functionality preserved for valid use cases
3. **Improves UX**: Better messaging and feedback for users
4. **Ensures Data Integrity**: Multi-layer validation prevents inconsistent states

The system now properly handles the distinction between draft and scheduled events, providing appropriate user feedback while maintaining the flexibility needed for various event management workflows.
