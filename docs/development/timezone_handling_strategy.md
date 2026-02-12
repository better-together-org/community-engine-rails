# Timezone Handling Strategy

## Table of Contents

1. [Overview](#overview)
2. [Core Principles](#core-principles)
3. [Architecture](#architecture)
   - Database Schema
   - Models (Event, Platform, Person)
   - Attribute Aliasing Concern
4. [Request-Level Timezone Handling](#request-level-timezone-handling)
   - Controller Configuration
   - Priority Hierarchy
5. [Form Helpers](#form-helpers)
   - IANA Timezone Select Helper
   - Default Timezone Helper
6. [View Display](#view-display)
   - Formatting Times in Views
   - Localization Formats
7. [Action Cable Channels](#action-cable-channels)
   - Channel Timezone Handling
   - Client-Side Timezone Handling
8. [Background Jobs](#background-jobs)
   - ActiveJob/Sidekiq Timezone Handling
   - Scheduling Jobs with Timezones
   - Sidekiq Cron/Periodic Jobs
9. [Action Mailer](#action-mailer)
   - Mailer Timezone Context
   - Mailer Views with Timezone
10. [JavaScript & Client-Side Handling](#javascript--client-side-handling)
    - Receiving Times from Server
    - Stimulus Controller for Timezone Display
    - Sending Times to Server
11. [API Responses](#api-responses)
    - JSON Serialization
    - Controller API Responses
12. [Rake Tasks & Scripts](#rake-tasks--scripts)
    - Rake Task Timezone Context
    - Rails Console Scripts
13. [Testing](#testing)
    - Test Configuration
    - Testing Timezone-Specific Behavior
    - Factory Configuration
    - Testing Channels
    - Testing Background Jobs
    - Testing Mailers
    - Testing API Responses
14. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
15. [Migration Path](#migration-path)
16. [References](#references)
17. [Checklist for New Features](#checklist-for-new-features)
18. [Support](#support)

## Overview

The Better Together Community Engine implements industry best practices for timezone management, ensuring accurate time representation across global users while maintaining data integrity and developer ergonomics.

This guide covers timezone handling across all Rails mechanisms including controllers, views, models, Action Cable channels, background jobs, mailers, JavaScript, APIs, and console scripts.

## Core Principles

### 1. **Store Everything in UTC**
- All `datetime` columns in the database store times in UTC
- Rails automatically converts all times to UTC before database storage
- Never store times in local/user timezones in the database

### 2. **Store IANA Timezone Identifiers**
- Always use IANA timezone identifiers (e.g., `America/New_York`, `Europe/London`)
- **NEVER** use Rails timezone names (e.g., "Eastern Time (US & Canada)")
- IANA identifiers handle daylight saving time transitions correctly
- Validated against `TZInfo::Timezone.all_identifiers`

### 3. **Convert for Display Only**
- Convert UTC times to user's timezone when displaying
- Parse user input in the current request's timezone context
- Never store the converted times back to the database

## Architecture

### Database Schema

```ruby
# Events table
t.datetime :starts_at              # Stored in UTC
t.datetime :ends_at                # Stored in UTC
t.string :timezone, null: false    # IANA identifier (e.g., "America/New_York")

# Platforms table
t.string :time_zone                # IANA identifier (e.g., "UTC")

# People table (JSON column)
store_attributes :preferences do
  time_zone String                 # IANA identifier (e.g., "America/St_Johns")
end
```

### Models

#### Event Model
```ruby
class Event < ApplicationRecord
  validates :timezone, presence: true, inclusion: {
    in: -> { TZInfo::Timezone.all_identifiers },
    message: '%<value>s is not a valid timezone'
  }

  # Convert stored UTC time to event's timezone for display
  def local_starts_at
    starts_at.in_time_zone(timezone)
  end

  def local_ends_at
    ends_at.in_time_zone(timezone)
  end
end
```

#### Platform Model
```ruby
class Platform < ApplicationRecord
  validates :time_zone, presence: true, inclusion: {
    in: -> { TZInfo::Timezone.all_identifiers },
    message: '%<value>s is not a valid timezone'
  }
end
```

#### Person Model
```ruby
class Person < ApplicationRecord
  store_attributes :preferences do
    time_zone String, default: ENV.fetch('APP_TIME_ZONE', 'America/St_Johns')
  end

  # Custom setter ensures proper persistence in JSON store
  def time_zone=(value)
    prefs = (preferences || {}).dup
    prefs['time_zone'] = value&.to_s
    self.preferences = prefs
  end
end
```

### Attribute Aliasing Concern

The `TimezoneAttributeAliasing` concern provides backward compatibility between `timezone` and `time_zone` naming conventions:

```ruby
module TimezoneAttributeAliasing
  extend ActiveSupport::Concern

  # Handles both timezone/time_zone getters and setters
  # Works with columns, store_attributes, and late-bound attributes
  def method_missing(method_name, *args, &block)
    case method_name
    when :timezone
      respond_to?(:time_zone, true) ? time_zone : super
    when :timezone=
      respond_to?(:time_zone=, true) ? self.time_zone = args.first : super
    when :time_zone
      respond_to?(:timezone, true) ? timezone : super
    when :time_zone=
      respond_to?(:timezone=, true) ? self.timezone = args.first : super
    else
      super
    end
  end
end
```

**Usage**: Include in models that have timezone attributes:
```ruby
class Event < ApplicationRecord
  include TimezoneAttributeAliasing
  # Now responds to both .timezone and .time_zone
end
```

## Request-Level Timezone Handling

### Controller Configuration

```ruby
class ApplicationController < ActionController::Base
  around_action :set_time_zone

  private

  def set_time_zone(&block)
    tz = determine_timezone
    Time.use_zone(tz, &block)
  end

  def determine_timezone
    # Priority hierarchy: user → platform → app config → UTC
    user_tz = current_user&.person&.time_zone.presence
    return user_tz if user_tz

    platform_tz = helpers.host_platform&.time_zone.presence
    return platform_tz if platform_tz

    app_tz = Rails.application.config.time_zone.presence
    return app_tz if app_tz

    'UTC'
  end
end
```

**How it works**:
1. `around_action` sets `Time.zone` for the entire request
2. All time parsing/formatting in views and controllers uses this timezone
3. Rails automatically converts times back to UTC before database storage
4. The timezone context is released at the end of the request

### Priority Hierarchy

1. **User Timezone** (highest priority)
   - Stored in `person.preferences.time_zone`
   - Most specific to individual user

2. **Platform Timezone**
   - Stored in `platform.time_zone`
   - Organization/community-wide preference

3. **Application Config**
   - Set via `config.time_zone` in `config/application.rb`
   - System-wide default

4. **UTC** (fallback)
   - Universal safe fallback
   - Never fails

## Form Helpers

### IANA Timezone Select Helper

```ruby
# app/helpers/better_together/application_helper.rb

def iana_time_zone_select(object_name, method, priority_or_selected = nil, options = {}, html_options = {})
  selected = options[:selected] || options[:default]
  choices = iana_timezone_options_for_select

  if object_name.respond_to?(:select)
    # FormBuilder - use its select method with IANA options
    object_name.select(method, choices, options.merge(selected: selected), html_options)
  else
    # String object_name - use regular select helper
    select(object_name, method, choices, options.merge(selected: selected), html_options)
  end
end

def iana_timezone_options_for_select
  TZInfo::Timezone.all_identifiers.sort.map do |tz_id|
    tz = ActiveSupport::TimeZone[tz_id]
    display = tz ? "#{tz} (#{tz_id})" : tz_id
    [display, tz_id]
  rescue StandardError
    [tz_id, tz_id]
  end
end
```

**Usage in forms**:
```erb
<%= form_with model: @event do |f| %>
  <%= f.label :timezone %>
  <%= iana_time_zone_select(f, :timezone, selected: @event.timezone) %>
<% end %>
```

### Default Timezone Helper

```ruby
def default_timezone_for_event(event)
  event_timezone_preference(event) || 
  person_timezone_preference || 
  platform_timezone_preference || 
  'UTC'
end
```

## View Display

### Formatting Times in Views

```erb
<%# Display event time in event's timezone %>
<%= l(event.local_starts_at, format: :long) %>

<%# Display in current user's timezone %>
<%= l(event.starts_at.in_time_zone(Time.zone), format: :long) %>

<%# Show timezone info %>
<%= event.timezone_display %>
<!-- Output: "Eastern Time (US & Canada) (America/New_York)" -->
```

### Localization Formats

Configure datetime formats in locale files:

```yaml
# config/locales/en.yml
en:
  time:
    formats:
      event_date_time: "%b %-d, %I:%M %p"
      event_date_time_with_year: "%b %-d, %Y %I:%M %p"
      time_only: "%I:%M %p"
      time_only_with_year: "%I:%M %p %Y"
```

## JavaScript/Stimulus Integration

### Auto-detect Browser Timezone

```javascript
// app/javascript/controllers/better_together/time_zone_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    const ianaTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone
    this.selectTimezone(ianaTimeZone)
  }

  selectTimezone(ianaTimeZone) {
    const options = this.selectTarget.options
    for (let i = 0; i < options.length; i++) {
      if (options[i].value === ianaTimeZone) {
        this.selectTarget.selectedIndex = i
        break
      }
    }
  }
}
```

**Usage**:
```erb
<div data-controller="better-together--time-zone">
  <%= iana_time_zone_select('platform', :time_zone, nil, 
      { selected: @platform.time_zone }, 
      { class: 'form-select', 
        'data-better-together--time-zone-target': 'select' }) %>
</div>
```

## Action Cable Channels

### Channel Timezone Handling

Action Cable channels run outside the normal request/response cycle and don't have access to `around_action` filters. Times must be explicitly handled:

```ruby
# app/channels/better_together/notifications_channel.rb
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  # When broadcasting, always send UTC timestamps
  def self.broadcast_notification(user, notification)
    broadcast_to user, {
      id: notification.id,
      message: notification.message,
      created_at: notification.created_at.utc.iso8601, # UTC ISO8601
      timezone: user.person.time_zone # Send user's timezone for client conversion
    }
  end
end
```

### Client-Side Timezone Handling

```javascript
// app/javascript/channels/better_together/notifications_channel.js
import consumer from "../consumer"

consumer.subscriptions.create("BetterTogether::NotificationsChannel", {
  received(data) {
    // Parse UTC timestamp
    const utcDate = new Date(data.created_at)
    
    // Convert to user's timezone (browser handles this automatically)
    const localTime = utcDate.toLocaleString('en-US', {
      timeZone: data.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone,
      hour: '2-digit',
      minute: '2-digit'
    })
    
    this.displayNotification(data.message, localTime)
  }
})
```

**Key Principles**:
- Always broadcast times as UTC ISO8601 strings
- Include user's timezone preference in payload if needed
- Let client-side JavaScript handle timezone conversion
- Use `toISOString()` or `.utc.iso8601` for serialization

## Background Jobs

### ActiveJob/Sidekiq Timezone Handling

Background jobs run without user context. Handle timezones explicitly:

```ruby
# app/jobs/better_together/send_event_reminder_job.rb
class SendEventReminderJob < ApplicationJob
  queue_as :notifications

  # Pass timezone as parameter, not user object
  def perform(event_id, user_id, user_timezone)
    event = Event.find(event_id)
    user = User.find(user_id)
    
    # Use Time.use_zone for scoped timezone context
    Time.use_zone(user_timezone) do
      reminder_time = event.starts_at.in_time_zone(user_timezone)
      EventReminderMailer.send_reminder(
        user: user,
        event: event,
        reminder_time: reminder_time
      ).deliver_now
    end
  end
end
```

### Scheduling Jobs with Timezones

```ruby
# Schedule job to run at specific time in user's timezone
class EventsController < ApplicationController
  def create
    @event = Event.new(event_params)
    
    if @event.save
      # Schedule reminder 1 hour before event in event's timezone
      reminder_time = @event.starts_at - 1.hour
      
      SendEventReminderJob.set(wait_until: reminder_time)
        .perform_later(
          @event.id,
          current_user.id,
          current_user.person.time_zone # Pass timezone as string
        )
    end
  end
end
```

### Sidekiq Cron/Periodic Jobs

```ruby
# config/initializers/sidekiq.rb
# For recurring jobs, specify timezone explicitly
Sidekiq.configure_server do |config|
  config[:cron_timezone] = 'UTC' # Always use UTC for cron schedules
  
  config[:schedule] = {
    'daily_digest' => {
      'cron' => '0 9 * * *', # 9 AM UTC
      'class' => 'DailyDigestJob'
    }
  }
end
```

**Best Practices**:
- Pass timezone strings as job arguments, not full user/platform objects
- Use `Time.use_zone` for scoped context within job
- Schedule jobs in UTC, convert display times per user
- Serialize times as UTC when enqueueing
- Test jobs with explicit timezone context

## Action Mailer

### Mailer Timezone Context

Emails should display times in the recipient's timezone:

```ruby
# app/mailers/better_together/event_mailer.rb
class EventMailer < ApplicationMailer
  def event_invitation(user, event)
    @user = user
    @event = event
    @user_timezone = user.person.time_zone
    
    # Set timezone context for view rendering
    Time.use_zone(@user_timezone) do
      @formatted_start_time = l(event.starts_at.in_time_zone(@user_timezone), 
                                 format: :long)
      @formatted_end_time = l(event.ends_at.in_time_zone(@user_timezone), 
                               format: :long)
      
      mail to: user.email,
           subject: t('event_mailer.invitation.subject', event_title: event.title)
    end
  end
end
```

### Mailer Views with Timezone

```erb
<%# app/views/better_together/event_mailer/event_invitation.html.erb %>
<h2><%= t('.greeting', name: @user.name) %></h2>

<p><%= t('.invited_to', event: @event.title) %></p>

<ul>
  <li><strong><%= t('.starts') %>:</strong> <%= @formatted_start_time %></li>
  <li><strong><%= t('.ends') %>:</strong> <%= @formatted_end_time %></li>
  <li><strong><%= t('.timezone') %>:</strong> <%= @event.timezone_display %></li>
</ul>

<%# Always show timezone so recipient knows the context %>
<p class="text-muted">
  <%= t('.times_shown_in_timezone', timezone: @user_timezone) %>
</p>
```

**Best Practices**:
- Always use `Time.use_zone` in mailer methods
- Format times in recipient's timezone, not sender's
- Display timezone information in email body
- Test mailers with different timezone contexts
- Include calendar attachment (ICS) with UTC times

## JavaScript & Client-Side Handling

### Receiving Times from Server

```javascript
// Always parse as UTC ISO8601 strings from server
class TimeDisplay {
  constructor(utcTimestamp, userTimezone) {
    this.utcDate = new Date(utcTimestamp) // Parses ISO8601 as UTC
    this.userTimezone = userTimezone || this.detectBrowserTimezone()
  }
  
  detectBrowserTimezone() {
    return Intl.DateTimeFormat().resolvedOptions().timeZone
  }
  
  format(options = {}) {
    const defaultOptions = {
      timeZone: this.userTimezone,
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    }
    
    return this.utcDate.toLocaleString('en-US', { ...defaultOptions, ...options })
  }
}

// Usage
const eventTime = new TimeDisplay('2025-09-04T14:00:00Z', 'America/New_York')
console.log(eventTime.format()) // "Sep 4, 2025, 10:00 AM" (EDT)
```

### Stimulus Controller for Timezone Display

```javascript
// app/javascript/controllers/better_together/time_display_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    utcTime: String,
    timezone: String,
    format: { type: String, default: 'short' }
  }
  
  connect() {
    this.displayLocalTime()
  }
  
  displayLocalTime() {
    const utcDate = new Date(this.utcTimeValue)
    const userTimezone = this.timezoneValue || this.browserTimezone()
    
    const formats = {
      short: { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' },
      long: { dateStyle: 'full', timeStyle: 'short' },
      time: { hour: '2-digit', minute: '2-digit' }
    }
    
    const formatted = utcDate.toLocaleString('en-US', {
      timeZone: userTimezone,
      ...formats[this.formatValue]
    })
    
    this.element.textContent = formatted
  }
  
  browserTimezone() {
    return Intl.DateTimeFormat().resolvedOptions().timeZone
  }
}
```

**Usage in views**:
```erb
<span data-controller="better-together--time-display"
      data-better-together--time-display-utc-time-value="<%= event.starts_at.utc.iso8601 %>"
      data-better-together--time-display-timezone-value="<%= current_user.person.time_zone %>"
      data-better-together--time-display-format-value="long">
  Loading...
</span>
```

### Sending Times to Server

```javascript
// When submitting forms with datetime inputs
class DateTimeSubmitter {
  static prepareForServer(localDateTime, timezone) {
    // Create date object in user's timezone
    const date = new Date(localDateTime)
    
    // Convert to UTC ISO8601 for server
    return date.toISOString() // "2025-09-04T14:00:00.000Z"
  }
}

// In Stimulus controller
submitDateTime(event) {
  const localInput = this.element.querySelector('#event_starts_at').value
  const timezone = this.element.querySelector('#event_timezone').value
  
  const utcTimestamp = DateTimeSubmitter.prepareForServer(localInput, timezone)
  
  // Send to server
  fetch('/events', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      event: {
        starts_at: utcTimestamp,
        timezone: timezone
      }
    })
  })
}
```

## API Responses

### JSON Serialization

Always return times as UTC ISO8601 strings in JSON responses:

```ruby
# app/serializers/better_together/event_serializer.rb
class EventSerializer
  def initialize(event, user_timezone: nil)
    @event = event
    @user_timezone = user_timezone
  end
  
  def as_json
    {
      id: @event.id,
      title: @event.title,
      starts_at: @event.starts_at.utc.iso8601, # UTC ISO8601
      ends_at: @event.ends_at.utc.iso8601,
      timezone: @event.timezone, # IANA identifier
      # Optional: Include formatted local time for convenience
      local_starts_at: @user_timezone ? 
        @event.starts_at.in_time_zone(@user_timezone).iso8601 : nil
    }
  end
end
```

### Controller API Responses

```ruby
# app/controllers/api/v1/events_controller.rb
class Api::V1::EventsController < BetterTogether::Api::ApplicationController
  def show
    event = Event.find(params[:id])
    user_timezone = current_user&.person&.time_zone || 'UTC'
    
    render json: EventSerializer.new(event, user_timezone: user_timezone).as_json
  end
  
  def create
    # Accept ISO8601 UTC timestamps from client
    event_params = params.require(:event).permit(:title, :starts_at, :ends_at, :timezone)
    
    # Rails automatically parses ISO8601 and stores as UTC
    @event = Event.new(event_params)
    
    if @event.save
      render json: EventSerializer.new(@event).as_json, status: :created
    else
      render json: { errors: @event.errors }, status: :unprocessable_entity
    end
  end
end
```

**API Standards**:
- Always return UTC timestamps in ISO8601 format (`2025-01-15T14:00:00Z`)
- Include timezone field separately as IANA identifier
- Client handles conversion to local timezone
- Accept ISO8601 UTC timestamps in requests
- Document timezone expectations in API docs

## Rake Tasks & Scripts

### Rake Task Timezone Context

Rake tasks don't have user or request context:

```ruby
# lib/tasks/better_together/events.rake
namespace :better_together do
  namespace :events do
    desc 'Send reminders for upcoming events'
    task send_reminders: :environment do
      # Explicitly set timezone context
      Time.zone = ENV.fetch('TASK_TIMEZONE', 'UTC')
      
      Event.upcoming.find_each do |event|
        event.attendees.each do |attendee|
          user_timezone = attendee.person.time_zone
          
          # Use scoped timezone for each user
          Time.use_zone(user_timezone) do
            SendEventReminderJob.perform_later(
              event.id,
              attendee.id,
              user_timezone
            )
          end
        end
      end
    end
  end
end
```

### Rails Console Scripts

```ruby
# When running scripts in Rails console
# Always set Time.zone explicitly

# BAD - Uses server's system timezone
Time.now # Could be server's local time

# GOOD - Uses Rails configured timezone
Time.zone = 'America/New_York'
Time.zone.now # Explicit timezone context

# BEST - Use UTC for queries, convert for display
Time.zone = 'UTC'
events = Event.where('starts_at > ?', Time.current)
events.each do |event|
  puts event.starts_at.in_time_zone(event.timezone).strftime('%Y-%m-%d %I:%M %p %Z')
end
```

## Testing

### Test Configuration

```ruby
# spec/spec_helper.rb or spec/rails_helper.rb
RSpec.configure do |config|
  # Ensure consistent timezone in tests
  config.before(:suite) do
    Time.zone = 'UTC'
  end
end
```

### Testing Timezone-Specific Behavior

```ruby
# spec/helpers/better_together/events_helper_spec.rb
RSpec.describe EventsHelper do
  # Explicitly set event timezone to match expected output
  let(:event) { create(:event, starts_at: start_time, timezone: 'UTC') }
  let(:start_time) { Time.zone.parse('2025-09-04 14:00:00') }

  it 'displays time in event timezone' do
    expect(helper.display_event_time(event)).to eq('Sep 4, 2025 2:00 PM')
  end
end
```

### Factory Configuration

```ruby
# spec/factories/better_together/events.rb
FactoryBot.define do
  factory :event do
    timezone { 'America/New_York' }  # Use IANA identifier
    starts_at { 1.week.from_now }
    ends_at { 1.week.from_now + 2.hours }
  end
end
```

### Testing Channels

```ruby
# spec/channels/better_together/notifications_channel_spec.rb
RSpec.describe NotificationsChannel do
  let(:user) { create(:user) }
  
  it 'broadcasts notification with UTC timestamp' do
    notification = create(:notification)
    
    expect {
      NotificationsChannel.broadcast_notification(user, notification)
    }.to have_broadcasted_to(user).with(hash_including(
      created_at: notification.created_at.utc.iso8601
    ))
  end
end
```

### Testing Background Jobs

```ruby
# spec/jobs/better_together/send_event_reminder_job_spec.rb
RSpec.describe SendEventReminderJob do
  let(:event) { create(:event, starts_at: Time.zone.parse('2025-09-04 14:00:00'), timezone: 'America/New_York') }
  let(:user) { create(:user) }
  
  before do
    user.person.update(time_zone: 'America/Los_Angeles')
  end
  
  it 'formats reminder in user timezone' do
    # Job receives timezone as string parameter
    described_class.perform_now(event.id, user.id, user.person.time_zone)
    
    # Verify email was sent with correct timezone formatting
    mail = ActionMailer::Base.deliveries.last
    expect(mail.body.encoded).to include('America/Los_Angeles')
  end
end
```

### Testing Mailers

```ruby
# spec/mailers/better_together/event_mailer_spec.rb
RSpec.describe EventMailer do
  let(:user) { create(:user) }
  let(:event) { create(:event, starts_at: Time.zone.parse('2025-09-04 18:00:00 UTC'), timezone: 'UTC') }
  
  before do
    user.person.update(time_zone: 'America/New_York')
  end
  
  describe '#event_invitation' do
    let(:mail) { described_class.event_invitation(user, event) }
    
    it 'formats time in recipient timezone' do
      # Event at 18:00 UTC should be 14:00 (2:00 PM) EDT
      expect(mail.body.encoded).to include('2:00 PM')
      expect(mail.body.encoded).to include('America/New_York')
    end
  end
end
```

### Testing API Responses

```ruby
# spec/requests/api/v1/events_spec.rb
RSpec.describe 'API V1 Events', type: :request do
  describe 'GET /api/v1/events/:id' do
    let(:event) { create(:event, starts_at: Time.zone.parse('2025-09-04 14:00:00 UTC')) }
    
    it 'returns UTC ISO8601 timestamp' do
      get api_v1_event_path(event), headers: api_headers
      
      json = JSON.parse(response.body)
      
      # Verify ISO8601 format with Z (UTC) indicator
      expect(json['starts_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      expect(json['timezone']).to eq(event.timezone)
    end
  end
end
```

## Common Pitfalls & Solutions

### ❌ **DON'T: Use Rails Timezone Names**
```ruby
# WRONG - Rails timezone name
event.timezone = "Eastern Time (US & Canada)"
```

### ✅ **DO: Use IANA Identifiers**
```ruby
# CORRECT - IANA identifier
event.timezone = "America/New_York"
```

---

### ❌ **DON'T: Store Local Times**
```ruby
# WRONG - Storing time in user's timezone
event.starts_at = Time.zone.now  # If Time.zone is user's timezone
```

### ✅ **DO: Store UTC, Display Local**
```ruby
# CORRECT - Store in UTC, convert for display
event.starts_at = Time.current  # Always UTC
display_time = event.starts_at.in_time_zone(user_timezone)
```

---

### ❌ **DON'T: Use `Time.zone` Globally**
```ruby
# WRONG - Changes global state
Time.zone = user.time_zone
```

### ✅ **DO: Use `Time.use_zone` Block**
```ruby
# CORRECT - Temporary context
Time.use_zone(user.time_zone) do
  formatted_time = event.starts_at.strftime('%I:%M %p')
end
```

---

### ❌ **DON'T: Parse Without Timezone Context**
```ruby
# WRONG - Ambiguous parsing
Time.parse("2025-01-15 14:00")
```

### ✅ **DO: Parse in Specific Timezone**
```ruby
# CORRECT - Explicit timezone context
Time.zone.parse("2025-01-15 14:00")  # Uses Time.zone
Time.find_zone("America/New_York").parse("2025-01-15 14:00")
```

---

### ❌ **DON'T: Mix `timestamp without time zone` and Manual Timezone Handling**
```ruby
# WRONG - PostgreSQL column type without Rails handling
execute "ALTER TABLE events ALTER COLUMN starts_at TYPE timestamp"
```

### ✅ **DO: Use Rails Datetime with UTC Default**
```ruby
# CORRECT - Let Rails handle timezone conversion
t.datetime :starts_at, null: false
# Or for PostgreSQL native timezone support:
execute "ALTER TABLE events ALTER COLUMN starts_at TYPE timestamptz"
```

## Migration Path

### Future Enhancement: PostgreSQL `timestamptz`

While Rails handles UTC conversion correctly with `timestamp without time zone`, using `timestamptz` provides native PostgreSQL timezone support:

```ruby
class ConvertToTimestamptz < ActiveRecord::Migration[7.2]
  def up
    # Convert existing columns to timestamptz
    execute <<-SQL
      ALTER TABLE better_together_events 
      ALTER COLUMN starts_at TYPE timestamptz USING starts_at AT TIME ZONE 'UTC';
      
      ALTER TABLE better_together_events 
      ALTER COLUMN ends_at TYPE timestamptz USING ends_at AT TIME ZONE 'UTC';
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE better_together_events 
      ALTER COLUMN starts_at TYPE timestamp USING starts_at AT TIME ZONE 'UTC';
      
      ALTER TABLE better_together_events 
      ALTER COLUMN ends_at TYPE timestamp USING ends_at AT TIME ZONE 'UTC';
    SQL
  end
end
```

**Benefits**:
- PostgreSQL can use native timezone-aware functions
- More explicit about UTC storage
- Better interoperability with other tools

**Note**: This is optional - current implementation works correctly.

## References

- [PostgreSQL Don't Use timestamp without time zone](https://wiki.postgresql.org/wiki/Don't_Do_This#Don.27t_use_timestamp_.28without_time_zone.29)
- [Rails Timezone Best Practices](https://thoughtbot.com/blog/its-about-time-zones)
- [IANA Time Zone Database](https://www.iana.org/time-zones)
- [TZInfo Documentation](https://github.com/tzinfo/tzinfo)

## Checklist for New Features

When adding datetime functionality:

**Database & Models**:
- [ ] Database columns use `t.datetime` (stores UTC)
- [ ] Timezone columns validated against `TZInfo::Timezone.all_identifiers`
- [ ] Model includes `TimezoneAttributeAliasing` if applicable
- [ ] Factory uses IANA identifier for timezone

**Controllers & Views**:
- [ ] Controller has `around_action :set_time_zone` if needed
- [ ] Forms use `iana_time_zone_select` helper
- [ ] Display uses `.in_time_zone()` for conversion
- [ ] JavaScript auto-detection implemented if user-facing

**Background Processing**:
- [ ] Jobs receive timezone as string parameter (not objects)
- [ ] Jobs use `Time.use_zone()` for scoped timezone context
- [ ] Scheduled jobs use UTC for cron schedules
- [ ] Job tests verify timezone handling

**Communication**:
- [ ] Mailers use `Time.use_zone()` for recipient's timezone
- [ ] Mailer views display timezone information
- [ ] Channels broadcast UTC ISO8601 timestamps
- [ ] Channel payloads include timezone field if needed

**API & JavaScript**:
- [ ] API responses return UTC ISO8601 format (`2025-01-15T14:00:00Z`)
- [ ] API includes timezone field as IANA identifier
- [ ] JavaScript parses UTC timestamps from server
- [ ] Stimulus controllers handle timezone display
- [ ] Client-side code uses `Intl.DateTimeFormat` for formatting

**Testing**:
- [ ] Tests explicitly set timezone context
- [ ] Channel tests verify UTC timestamp format
- [ ] Job tests verify timezone parameter handling
- [ ] Mailer tests verify recipient timezone formatting
- [ ] API tests verify ISO8601 UTC format
- [ ] Feature tests verify timezone display in UI

**Documentation**:
- [ ] Documentation updated with timezone considerations
- [ ] API docs specify timezone expectations
- [ ] User-facing docs explain timezone behavior

## Support

For questions or issues with timezone handling, refer to:
- This document
- `app/controllers/better_together/application_controller.rb` (request-level handling)
- `app/helpers/better_together/application_helper.rb` (form helpers)
- `app/models/concerns/better_together/timezone_attribute_aliasing.rb` (aliasing concern)
- `app/channels/better_together/` (Action Cable channel examples)
- `app/jobs/better_together/` (Background job examples)
- `app/mailers/better_together/` (Mailer examples)
