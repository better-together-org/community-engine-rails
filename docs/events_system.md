# Events & Calendars

This## What's Implemented
- **RSVPs/Attendees**: `EventAttendance` model with `person_id`, `event_id`, `status` (interested/going/not_going), guarded by privacy/policy.
- **ICS Export**: Export endpoint at `/events/:id/ics` that renders VEVENT from name/description/time/location.

## What's Not Implemented Yet
- **Recurrence**: No repeat rules; all events are single instances.
- **Calendar Entries**: `CalendarEntry` exists but is not used to associate events to calendars.
- **Event Location/Address**: Address association is commented out; no geocoding integration active.
- **Advanced RSVP Features**: No waitlists, capacity limits, or guest allowances.
- **Event Reminders**: No notification system for upcoming events.
- **Event Updates/Changes**: No notification system when event details change.
- **Bulk Operations**: No bulk event creation, editing, or management tools.e explains the Event model, how events are created and displayed, how visibility works, and how calendars fit in. It also notes what is not yet implemented (RSVPs, attendees, recurrence) so maintainers know the current scope.

## Event Attendance & RSVPs
- Model: `BetterTogether::EventAttendance`
- Associations: `belongs_to :event`, `belongs_to :person`
- Status enum: `interested`, `going`, `not_going`
- Policy: `EventAttendancePolicy` controls who can create/update attendance
- Controller actions: `rsvp_interested`, `rsvp_going`, `rsvp_cancel` on EventsController
- Workflow: Users can RSVP as interested/going, or cancel their RSVP (destroys attendance record)
- Authorization: Requires login; guests cannot RSVP

## ICS Calendar Export
- Route: `GET /events/:id/ics` with format defaulted to `:ics`
- Controller action: `ics` on EventsController
- MIME type: Registered as `text/calendar` for `.ics` extension
- Content: Generates valid iCalendar (RFC 5545) with VEVENT containing:
  - SUMMARY (event name)
  - DESCRIPTION (sanitized ActionText description + view details URL)
  - DTSTART/DTEND (UTC timestamps)
  - UID (unique identifier: `event-{id}@better-together`)
  - URL (link back to event page)
- Authorization: Uses same policy as `show?` (public events or creator/manager access)

## Event Model
- Class: `BetterTogether::Event`
- Purpose: Represent a schedulable event with optional media and location.
- Traits: `Attachments::Images`, `Categorizable`, `Creatable`, `FriendlySlug`, `Geography::Geospatial::One`, `Geography::Locatable::One`, `Identifier`, `Privacy`, `TrackedActivity`, `Viewable`.
- Associations: `has_many :event_attendances`, `has_many :attendees` (through event_attendances -> person)
- Translated fields: `name` (string), `description` (ActionText).
- Images: `attachable_cover_image` (cover image support).
- Categories: `categorizable(class_name: 'BetterTogether::EventCategory')`.
- Scheduling fields: `starts_at` (required), `ends_at` (optional), `registration_url` (optional, validated URL).
- Validation: `ends_at` must be after `starts_at`.
- Scopes: `draft` (no starts_at), `upcoming` (starts_at >= now), `past` (starts_at < now).
- Privacy: Uses `Privacy` concern (public/private); policies enforce who may view/manage.
- Geocoding (optional): Includes geospatial/locatable concerns and has a `schedule_address_geocoding` path for when address/location is available (address association currently commented out).
- ICS Export: `to_ics` method generates iCalendar format for calendar applications.

## Controller & Views
- Controller: `BetterTogether::EventsController` (index groups into draft/upcoming/past)
- RSVP actions: `rsvp_interested`, `rsvp_going`, `rsvp_cancel` (require authentication)
- ICS export: `ics` action renders calendar file with proper MIME type
- Show/View: Uses FriendlySlug to present readable URLs and `Viewable` for basic metrics
- Creation: Standard CRUD with validations

## Calendars
- `BetterTogether::Calendar`: A named, translatable container linked to a Community (`belongs_to :community`), with privacy and slug.
- `BetterTogether::CalendarEntry`: Placeholder model for future association of events to calendar entries (not yet wired).

## What’s Not Implemented Yet
- RSVPs/Attendees: No attendance model or RSVP workflow.
- Recurrence: No repeat rules; all events are single instances.
- ICS Export: Not currently generating .ics files.
- Calendar Entries: `CalendarEntry` exists but is not used to associate events to calendars.

## How to Extend Safely
- Recurrence: Add a `recurrence_rule` string + service to materialize occurrences; ensure scopes reflect next occurrences.
- Calendar mapping: Create `CalendarEntry` with `calendar_id`, `event_id` and query by calendar.
