# Event Hosts Management UI Implementation Plan

**Date:** 2026-01-24  
**Status:** ✅ Complete

## Overview

Add a dedicated "Hosts" tab to the event form with an interface for adding and removing event hosts. New hosts display radio buttons for type selection; existing hosts show as read-only cards with remove buttons (disabled when only one host remains).

## Implementation Summary

Successfully implemented a comprehensive event hosts management UI with the following features:

- ✅ New "Hosts" tab in event form between "Details" and "Time & Place"
- ✅ Radio button selection for host types (Person, Community, and extensible to others via `HostsEvents.included_in_models`)
- ✅ Policy-scoped dropdown for selecting specific hosts based on type
- ✅ Read-only display of existing hosts with remove functionality
- ✅ Client-side and server-side validation preventing removal of last host
- ✅ ARIA live regions for accessibility announcements
- ✅ Comprehensive i18n support across all 4 locales (en, es, fr, uk)
- ✅ Automatic host pre-population (current_person as default when no other hosts exist)
- ✅ Support for pre-populating hosts via URL parameters (community/partner/venue)

## Files Created/Modified

### Models
- ✅ `app/models/better_together/event.rb` - Added `validates :event_hosts, length: { minimum: 1 }` and updated `permitted_attributes` to include destroy option

### Controllers
- ✅ `app/controllers/better_together/events_controller.rb` - Enhanced `build_event_hosts` to ensure current_person is default host, added `available_hosts` endpoint for policy-scoped host options

### Views
- ✅ `app/views/better_together/events/_form.html.erb` - Added "Hosts" tab, integrated event_hosts_controller Stimulus controller
- ✅ `app/views/better_together/events/_event_host_fields.html.erb` (NEW) - Partial for rendering individual host fields with conditional new/existing logic

### JavaScript
- ✅ `app/javascript/controllers/better_together/event_hosts_controller.js` (NEW) - Stimulus controller handling host type changes, AJAX loading, add/remove with validation, ARIA announcements

### Routes
- ✅ `config/routes.rb` - Added `get :available_hosts` collection route for events

### Translations (en, es, fr, uk)
- ✅ `config/locales/en.yml` - Added `events.tabs.hosts`, `events.hosts.*` keys, and validation error
- ✅ `config/locales/es.yml` - Spanish translations
- ✅ `config/locales/fr.yml` - French translations
- ✅ `config/locales/uk.yml` - Ukrainian translations

## Requirements

- Host type selection via radio buttons (only visible for new event host records) ✅
- Hosts can be removed but not edited after creation ✅
- Events must have at least one host at all times ✅
- Explanatory text that hosts can edit event details ✅
- Automatic support for any host type via `HostsEvents.included_in_models` ✅
- Pre-populate creator as default host when creating new events ✅

## Implementation Steps

### 1. Create new "Hosts" tab and content pane

**File:** `app/views/better_together/events/_form.html.erb`

- Add tab button between "Details" and "Time-and-place" tabs
- Use Bootstrap 5 vertical pills pattern
- Include proper ARIA attributes
- Integrate with `better_together--tabs_controller`
- Add introductory paragraph: "Event hosts can edit all event details and manage other hosts. Events must have at least one host."

### 2. Create `_event_host_fields.html.erb` partial

**File:** `app/views/better_together/events/_event_host_fields.html.erb`

- Conditional rendering based on `form.object.new_record?`
- Use `data-new-record` pattern from addresses
- **New records:**
  - Radio buttons for host type selection (generated from `HostsEvents.included_in_models`)
  - SlimSelect dropdown for selecting specific host
- **Existing records:**
  - Read-only display of `host.to_s` and host type
  - Remove button using `dynamic_fields_controller#remove` pattern

### 3. Server-side validation and controller pre-population

**Files:**
- `app/models/better_together/event.rb`
- `app/controllers/better_together/events_controller.rb`

**Model changes:**
- Add validation: `validates :event_hosts, length: { minimum: 1 }`

**Controller changes:**
- Modify `new` action or `build_event_hosts` before_action
- Ensure `event_hosts.build(host: current_person)` when `event_hosts.empty?`
- Check params first to allow community/partner/venue pre-population

### 4. Create `event_hosts_controller.js` Stimulus controller

**File:** `app/javascript/controllers/better_together/event_hosts_controller.js`

**Features:**
- Extend `dynamic_fields_controller`
- Override `remove()` method:
  - Count visible non-destroyed fields: `querySelectorAll('.nested-fields:not([style*="display: none"])')`
  - Show ARIA live error if count equals one
  - Prevent removal if only one host exists
- Handle radio button changes:
  - Fetch options via `GET /events/available_hosts?host_type=<ClassName>`
  - Populate SlimSelect dropdown
- Manage `data-new-record="true"` visibility

### 5. Add policy-scoped JSON endpoint

**Files:**
- `app/controllers/better_together/events_controller.rb`
- `config/routes.rb`

**Controller action:** `available_hosts`
- Validate `host_type` against `HostsEvents.included_in_models`
- Apply `Pundit.policy_scope!` to resolved class
- Filter by `valid_event_host_ids`
- Return JSON: `[{value: id, text: host.to_s}, ...]`

**Route:** `get 'events/available_hosts', to: 'events#available_hosts'`

### 6. Implement accessibility and I18n

**Accessibility:**
- ARIA live region for "Cannot remove last host" messages
- `aria-disabled="true"` on disabled remove buttons
- Keyboard navigation support
- Fieldset/legend for radio groups
- Focus management when adding hosts

**I18n keys (en/es/fr/uk):**
- `better_together.events.tabs.hosts` - Tab label
- `better_together.events.hosts.description` - Description paragraph
- `better_together.events.hosts.add_host` - Add button text
- `better_together.events.hosts.remove_host` - Remove button text
- `better_together.events.hosts.host_type` - Host type label
- `better_together.events.hosts.select_host` - Dropdown placeholder
- `better_together.events.hosts.cannot_remove_last` - Error message
- `activerecord.errors.models.better_together/event.attributes.event_hosts.too_short` - Validation error
- Host type labels via `activerecord.models.*`

## Technical Decisions

1. **Host count calculation:** Count visible non-destroyed fields to allow host replacement
2. **Display name:** Use `to_s` method for all host types
3. **Validation:** Both client-side (UX) and server-side (security)
4. **Creator pre-population:** Server-side in controller before rendering form

## Testing Requirements

- Request specs for `available_hosts` endpoint with policy scoping
- Model validation specs for minimum host requirement
- Controller specs for host pre-population logic
- Feature specs for host management workflow (add/remove)
- JavaScript specs for Stimulus controller (count validation, AJAX)

## Security Considerations

- Allow-list validation via `HostsEvents.included_in_models`
- Policy scoping on all host selections
- Server-side validation prevents bypassing client-side restrictions
