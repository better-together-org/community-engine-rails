# Events & Calendars

This document explains the Event model, how events are created and displayed, how visibility works, how calendars fit in, the comprehensive notification system for event reminders and updates, and the event hosting system.

## Database Schema

The Events & Calendars domain consists of five primary tables plus standard shared tables (translations, ActionText, etc.). All Better Together tables are created via `create_bt_table`, which adds `id: :uuid`, `lock_version`, and `timestamps` automatically.

- better_together_events
  - id (uuid), type (STI default: `BetterTogether::Event`), creator_id, identifier, privacy
  - starts_at, ends_at, duration_minutes, registration_url
  - Indexes: `bt_events_by_starts_at`, `bt_events_by_ends_at`, `by_better_together_events_privacy`
- better_together_event_attendances
  - id (uuid), event_id, person_id, status (string enum: interested, going)
  - Unique index: `by_event_and_person` on [event_id, person_id]
- better_together_event_hosts
  - id (uuid), event_id, host_id, host_type (polymorphic to Person/Community/etc.)
- better_together_calendars
  - id (uuid), community_id, creator_id, identifier, locale, privacy, protected
  - Translated: name, description (ActionText)
- better_together_calendar_entries
  - id (uuid), calendar_id, event_id, starts_at, ends_at, duration_minutes
  - Indexes: `bt_calendar_events_by_starts_at`, `bt_calendar_events_by_ends_at`, `by_calendar_and_event` on [calendar_id, event_id]

### ER Diagram

```mermaid
erDiagram
  BETTER_TOGETHER_EVENTS ||--o{ BETTER_TOGETHER_EVENT_ATTENDANCES : has
  BETTER_TOGETHER_EVENTS ||--o{ BETTER_TOGETHER_EVENT_HOSTS : has
  BETTER_TOGETHER_EVENTS ||--o{ BETTER_TOGETHER_CALENDAR_ENTRIES : appears_in
  BETTER_TOGETHER_CALENDARS ||--o{ BETTER_TOGETHER_CALENDAR_ENTRIES : has

  %% Polymorphic host relationship (host_type: Person/Community/...)
  BETTER_TOGETHER_EVENT_HOSTS }o..|| HOSTS : polymorphic

  BETTER_TOGETHER_EVENTS {
    uuid id PK
    string type
    uuid creator_id FK
    string identifier
    string privacy
    datetime starts_at
    datetime ends_at
    decimal duration_minutes
    string registration_url
    integer lock_version
    datetime created_at
    datetime updated_at
  }

  BETTER_TOGETHER_EVENT_ATTENDANCES {
    uuid id PK
    uuid event_id FK
    uuid person_id FK
    string status
    integer lock_version
    datetime created_at
    datetime updated_at
  }

  BETTER_TOGETHER_EVENT_HOSTS {
    uuid id PK
    uuid event_id FK
    uuid host_id
    string host_type
    integer lock_version
    datetime created_at
    datetime updated_at
  }

  BETTER_TOGETHER_CALENDARS {
    uuid id PK
    uuid community_id FK
    uuid creator_id FK
    string identifier
    string locale
    string privacy
    boolean protected
    integer lock_version
    datetime created_at
    datetime updated_at
  }

  BETTER_TOGETHER_CALENDAR_ENTRIES {
    uuid id PK
    uuid calendar_id FK
    uuid event_id FK
    datetime starts_at
    datetime ends_at
    decimal duration_minutes
    integer lock_version
    datetime created_at
    datetime updated_at
  }
```

**Diagram Files:**
- 📊 [Mermaid Source](../../diagrams/source/events_schema_erd.mmd) - Editable source
- 🖼️ [PNG Export](../../diagrams/exports/png/events_schema_erd.png) - High-resolution image
- 🎯 [SVG Export](../../diagrams/exports/svg/events_schema_erd.svg) - Vector graphics

## Process Flow Diagram

```mermaid
flowchart TD

  %% Create & Validate
  C1[New Event] --> C2[Set name, starts_at, ends_at?]
  C2 --> V1{ends_at > starts_at?}
  V1 -->|No| ERR[Validation error]
  V1 -->|Yes| SAVE[Save]

  %% Event Hosts System
  SAVE --> HOST[Assign Event Hosts]
  HOST --> DEFHOST[Set creator as default host]
  DEFHOST --> ADDHOST{Additional hosts?}
  ADDHOST -->|Yes| HOSTVAL[Validate host types\nHostsEvents concern]
  ADDHOST -->|No| HOSTS_DONE[Hosts configured]
  HOSTVAL --> EH[Create EventHost records]
  EH --> HOSTS_DONE

  %% Categorize & Media
  HOSTS_DONE --> CAT[Assign categories]
  HOSTS_DONE --> IMG[Attach cover image]

  %% Visibility & Scopes
  CAT --> PZ{privacy}
  IMG --> SCOPE{starts_at timing}
  SCOPE -->|nil| DRAFT[Draft]
  SCOPE -->|>= now| UPCOMING[Upcoming]
  SCOPE -->|< now| PAST[Past]

  %% Optional Geocoding & Location
  IMG --> GEO[Optional: geocoding job]
  GEO --> LOC[Event with location data]

  %% Attendance System
  LOC --> ATTEND[User attendance system]
  ATTEND --> RSV1[interested]
  ATTEND --> RSV2[going]
  ATTEND --> RSV3[not_going]

  %% ICS Export
  ATTEND --> ICS[ICS Export: /events/:id/ics]

  %% Notification System
  HOSTS_DONE --> NOTI[Event Notification System]
  NOTI --> REM[EventReminderSchedulerJob]
  REM --> REM1[3 days before]
  REM --> REM2[1 day before]
  REM --> REM3[2 hours before]
  REM --> REM4[15 minutes before]

  %% Update Notifications
  SAVE --> UPD[Event update notifications]
  UPD --> UPDNOT[EventUpdateNotifier]
  UPDNOT --> UPDATT[Notify all attendees]

  %% Privacy & Permissions
  PZ -->|public| PUB[Publicly visible]
  PZ -->|private| PRIV[Community/host visibility only]

  %% Calendar Integration
  LOC --> CAL[Calendar system]
  CAL --> CE[CalendarEntry associations]
  CE --> CC[Community calendars]
  CE --> PC[Personal calendars]

  classDef create fill:#e3f2fd
  classDef host fill:#f3e5f5
  classDef visibility fill:#e8f5e8
  classDef attend fill:#fff3e0
  classDef notify fill:#ffebee

  class C1,C2,V1,ERR,SAVE create
  class HOST,DEFHOST,ADDHOST,HOSTVAL,EH,HOSTS_DONE host
  class PZ,SCOPE,DRAFT,UPCOMING,PAST,PUB,PRIV visibility
  class ATTEND,RSV1,RSV2,RSV3,ICS attend
  class NOTI,REM,REM1,REM2,REM3,REM4,UPD,UPDNOT,UPDATT notify
```

**Diagram Files:**
- 📊 [Mermaid Source](../../diagrams/source/events_flow.mmd) - Editable source
- 🖼️ [PNG Export](../../diagrams/exports/png/events_flow.png) - High-resolution image
- 🎯 [SVG Export](../../diagrams/exports/svg/events_flow.svg) - Vector graphics

## Workflows

### RSVP Flow

```mermaid
flowchart LR
  U[Authenticated User] --> E{View Event}
  E -->|Policy: show?| V[Event visible]
  E -->|Not visible| D[Denied]
  V --> A{Choose RSVP}
  A -->|Interested| I[Create/Update EventAttendance status=interested]
  A -->|Going| G[Create/Update EventAttendance status=going]
  A -->|Cancel| C[Destroy EventAttendance]
  I --> R[Redirect to event with notice]
  G --> R
  C --> R

  classDef action fill:#e3f2fd
  class U,E,V,A,I,G,C,R action
```

**Diagram Files:**
- 📊 [Mermaid Source](../../diagrams/source/events_rsvp_flow.mmd)
- 🖼️ [PNG Export](../../diagrams/exports/png/events_rsvp_flow.png)
- 🎯 [SVG Export](../../diagrams/exports/svg/events_rsvp_flow.svg)

### Reminder Scheduling Timeline

```mermaid
timeline
  title Event Reminder Scheduling
  section Create/Update Event
    Save Event: triggers Scheduler
  section Evaluate Conditions
    Has attendees? : yes/no
    Starts in >24h? : schedule 24h job
    Starts in >1h? : schedule 1h job
    Starts in future? : schedule start-time job
  section Delivery
    Reminder job runs : loads going attendees
    For each attendee : Noticed => ActionCable + Email (batched)
```

**Diagram Files:**
- 📊 [Mermaid Source](../../diagrams/source/events_reminders_timeline.mmd)
- 🖼️ [PNG Export](../../diagrams/exports/png/events_reminders_timeline.png)
- 🎯 [SVG Export](../../diagrams/exports/svg/events_reminders_timeline.svg)

## What's Implemented
- **RSVPs/Attendees**: `EventAttendance` model with `person_id`, `event_id`, `status` (interested/going/not_going), guarded by privacy/policy.
- **Event Hosts**: Polymorphic `EventHost` model allowing multiple entities (People, Communities, Organizations) to host events.
- **ICS Export**: Export endpoint at `/events/:id/ics` that renders VEVENT from name/description/time/location.
- **Event Reminder System**: Comprehensive notification system for upcoming events with multiple delivery channels.
- **Event Update Notifications**: Automatic notifications when event details change.
- **Location Support**: Full location support with polymorphic `LocatableLocation` model.

## What's Not Implemented Yet
- **Recurrence**: No repeat rules; all events are single instances.
- **Calendar Entries**: `CalendarEntry` exists but is not used to associate events to calendars.
- **Advanced RSVP Features**: No waitlists, capacity limits, or guest allowances.
- **Bulk Operations**: No bulk event creation, editing, or management tools.

## Event Hosts System

### Overview
Events can have multiple hosts through the polymorphic `EventHost` model. This allows different types of entities (People, Communities, Organizations) to co-host events and share hosting responsibilities.

### Components
- **EventHost Model**: `BetterTogether::EventHost`
  - Join model between Events and hosts
  - Polymorphic relationship: `belongs_to :host, polymorphic: true`
  - Associates: `belongs_to :event`
  - Permitted attributes: `host_id`, `host_type`, `event_id`

- **HostsEvents Concern**: `BetterTogether::HostsEvents`
  - Must be included in models to permit them as event hosts
  - Provides associations: `has_many :event_hosts, as: :host` and `has_many :hosted_events`
  - Class method `included_in_models` returns allow-list of valid host types
  - Automatically included in `Person`, `Community`, and other hostable models

### Event Hosting Workflow

#### Creating Events with Hosts
1. When creating an event, creator is automatically set as default host
2. Additional hosts can be added through `event_hosts_attributes` in the form
3. Host validation ensures only authorized entities can be assigned as hosts
4. Policy validation through `Pundit.policy_scope!` filters available host options

#### Host Authorization & Permissions
- **Event Host Member Check**: `event_host_member?` method in `EventPolicy`
  - Allows host representatives to manage events they're hosting
  - Checks if user can represent any of the event's hosts
  - Uses `agent.valid_event_host_ids` to determine user's hostable entities
- **CRUD Permissions**: Event hosts can create, read, update, and delete events they host
- **Visibility**: Event hosts are displayed on event pages via `visible_event_hosts` helper

#### Host Display & Interaction
- **Event Cards**: Show host information on event listings
- **Event Details**: Full "Hosted By" section with host cards
- **Authorization Filter**: `visible_event_hosts` helper filters hosts by user permissions
- **Multi-Host Support**: Events can display multiple hosts in responsive grid layout

### Technical Implementation

#### Models & Associations
- **Event Model**: `has_many :event_hosts` and `has_many :hosts, through: :event_hosts`
- **Host Models**: Include `HostsEvents` concern for `event_hosts` and `hosted_events` associations
- **EventHost Model**: Polymorphic join table with validation and permitted attributes

#### Controller Integration
- **EventsController**: 
  - `build_event_hosts` method for form processing
  - `event_host_class` validation with allow-list checking
  - Host assignment through permitted parameters
- **Authorization**: Policy-based access control throughout the hosting workflow

#### Views & Helpers
- **Event Forms**: Nested form fields for `event_hosts_attributes`
- **Event Display**: `_event_hosts.html.erb` partial for consistent host display
- **Helper Methods**: `visible_event_hosts` centralizes authorization logic
- **I18n Support**: "Hosted By" labels with full translation coverage

### Security & Validation
- **Host Type Allow-List**: Only models including `HostsEvents` can be event hosts
- **Policy Validation**: All host assignments validated through Pundit policies  
- **Authorization Checks**: Host visibility and management permissions enforced
- **Creator Fallback**: Event creator automatically becomes default host

## Event Attendance & RSVPs

- Model: `BetterTogether::EventAttendance` with string enum `status` values: `interested`, `going`.
- Uniqueness: one attendance per [event, person].
- Controller: `EventsController` actions `rsvp_interested`, `rsvp_going`, `rsvp_cancel` update the record.
- Policy: `EventAttendancePolicy` enforces who may RSVP; guests cannot RSVP.
- UX: Buttons on event show page; counts for going/interested shown.

## Event Reminder & Notification System

### Components Overview
The event notification system consists of several integrated components:

- **EventReminderNotifier**: Noticed event class for sending event reminder notifications
- **EventReminderJob**: Background job for processing reminder notifications for all attendees
- **EventReminderSchedulerJob**: Schedules future reminder notifications at appropriate intervals
- **EventMailer**: Handles email delivery for event reminders and updates
- **EventUpdateNotifier**: Sends notifications when event details change

### Event Reminder Workflow

#### Scheduling Reminders
1. When an event is created or updated, `EventReminderSchedulerJob` is triggered
2. The scheduler calculates appropriate reminder times based on event start time:
   - **24 hours before**: For events more than 24 hours away
   - **1 hour before**: For events more than 1 hour away
   - **At start time**: For immediate notifications
3. Background jobs are scheduled using `perform_at` for each reminder interval
4. Only "going" attendees receive reminder notifications

#### Notification Delivery
1. `EventReminderJob` processes each scheduled reminder:
   - Finds all attendees with "going" status
   - Creates `EventReminderNotifier` instances for each attendee
   - Respects user notification preferences
2. `EventReminderNotifier` handles multi-channel delivery:
   - **Action Cable**: Real-time in-app notifications via `NotificationsChannel`
   - **Email**: HTML emails with event details (15-minute delay to batch notifications)
3. Email delivery is conditional based on:
   - User has email address configured
   - User has `notify_by_email` preference enabled
   - User has `event_reminders` preference enabled
   - Anti-spam: Only one email per unread event notifications

#### Event Update Notifications
1. When event details change, `EventUpdateNotifier` is triggered
2. Sends notifications to all attendees about the changes
3. Includes information about what specific attributes changed
4. Uses the same delivery channels as reminder notifications

### Notification Preferences
Users can control event notifications through their preferences:
- `event_reminders`: Enable/disable event reminder notifications
- `notify_by_email`: Enable/disable email notifications globally
- `show_conversation_details`: Control visibility of conversation details in emails

### Anti-Spam & Batching
- **Email Batching**: 15-minute delay on email delivery to group related notifications
- **Duplicate Prevention**: Only one email per unread notification group per event
- **Preference Respect**: All notifications respect user preferences and can be disabled

### Technical Implementation Details

#### Classes & Responsibilities
- **`BetterTogether::EventReminderNotifier`**: Noticed event class extending `ApplicationNotifier`
  - Handles multi-channel delivery (Action Cable + Email)
  - Includes anti-spam logic and preference checking
  - Generates localized notification content
- **`BetterTogether::EventReminderJob`**: Background job extending `ApplicationJob`
  - Processes events and finds "going" attendees
  - Creates notifier instances for each attendee
  - Handles error cases gracefully (missing events, connection issues)
  - Queue: `:notifications` with retry configuration
- **`BetterTogether::EventReminderSchedulerJob`**: Scheduling job
  - Calculates appropriate reminder intervals based on event timing
  - Schedules future `EventReminderJob` instances
  - Prevents scheduling reminders for past events or drafts
- **`BetterTogether::EventMailer`**: Mailer class extending `ApplicationMailer`
  - Renders HTML emails with event details
  - Uses Rails 7+ parameter pattern (`params[:key]`)
  - Includes event location, timing, and registration information
- **`BetterTogether::EventUpdateNotifier`**: Handles event change notifications
  - Triggers when event attributes are modified
  - Notifies all attendees (not just "going" status)
  - Includes information about what changed

#### Notification Timing Strategy
- **24-hour reminders**: For events starting more than 24 hours in the future
- **1-hour reminders**: For events starting more than 1 hour in the future
- **Start-time notifications**: For events starting within the hour
- **Update notifications**: Immediate when event details change

#### Queue & Background Processing
- Uses `:notifications` queue for all event-related jobs
- Retry configuration: Up to 5 attempts with polynomial backoff
- Discard policy: `ActiveRecord::RecordNotFound` errors are discarded
- Error handling: Jobs complete gracefully for missing/invalid events

### Models & Data Flow
- **Event**: Has many `event_attendances` and `attendees` (people)
- **EventAttendance**: Links person to event with status (interested/going/not_going)
- **Noticed::Notification**: Stores notification records with read/unread status
- **Noticed::Event**: Base class for all notifier events

### Testing Coverage
The event reminder system has comprehensive test coverage:

#### EventReminderNotifier Specs
- Tests notification content generation (title, body, identifiers)
- Validates parameter handling and defaults
- Verifies unread count inclusion in messages
- Uses mock objects following established patterns

#### EventReminderJob Specs  
- Tests attendee filtering and notification delivery
- Validates error handling for missing/invalid events
- Confirms queue configuration and retry policies
- Verifies reminder type parameter handling

#### EventMailer Specs
- Tests email rendering with event details
- Validates headers, subject lines, and recipient handling
- Tests localization support
- Confirms delivery methods work correctly

#### Integration Testing
- Tests complete notification workflow from event creation to delivery
- Validates preference-based filtering
- Tests anti-spam and batching behavior
- Ensures proper authorization checks
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
