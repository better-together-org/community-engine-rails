# Event Reminder UX Enhancement Implementation Plan

## ⚠️ COLLABORATIVE REVIEW REQUIRED

**This implementation plan must be reviewed collaboratively before implementation begins. The plan creator should:**

1. **Validate assumptions** with stakeholders and technical leads
2. **Confirm technical approach** aligns with platform values and architecture
3. **Review authorization patterns** match host community role-based permissions
4. **Verify UI/UX approach** follows cooperative and democratic principles
5. **Check timeline and priorities** against current platform needs

---

## Overview

Comprehensive enhancement of the event email reminder system to address critical UX gaps identified through detailed assessment. This implementation resolves 9 of 11 identified issues including timezone awareness, notification duplication prevention, cancellation/postponement flows, granular per-status/per-duration notification preferences, and event update categorization.

### Problem Statement

The current event reminder system has several critical gaps impacting user experience:

1. **No timezone awareness** - Events stored as naive UTC datetime causing DST bugs and international event timing errors
2. **Notification duplication on rapid edits** - Multiple edits trigger duplicate reminder jobs with no effective cancellation
3. **No cancellation/postponement notifications** - Attendees unaware when events are deleted or converted to draft
4. **Limited preference controls** - Only global email toggle; no granular control over event reminder types, timing, or attendance status
5. **Undifferentiated event updates** - All changes trigger same notification regardless of criticality
6. **No interested attendee reminders** - Users marking 'interested' receive zero notifications
7. **Missing privacy change notifications** - Attendees not notified when event privacy changes (deferred to future scope)
8. **No digest option** - Heavy event attendees receive separate emails for each event (deferred to future scope)

### Success Criteria

1. **Timezone accuracy**: Events display correctly across DST transitions and for international attendees
2. **Duplication prevention**: Rapid event edits (5+ updates within 2 minutes) result in only one set of reminder jobs
3. **Notification clarity**: Users receive distinct cancellation vs postponement notifications with appropriate copy
4. **Preference granularity**: Users can independently control 6 reminder preferences (going: 24h/1h/start; interested: 24h/1h/start) plus event updates and cancellations
5. **Update prioritization**: Critical changes (time/date) deliver immediately; important changes (name/location) wait 5 minutes; minor changes (description) wait 15 minutes
6. **Test coverage**: All new features covered by comprehensive specs including timezone edge cases, preference combinations, and notification flows
7. **i18n completeness**: All new strings translated to en, es, fr, uk locales

## Stakeholder Analysis

### Primary Stakeholders

- **End Users (Event Attendees)**: Need accurate event times in their timezone, control over reminder frequency/timing, clear distinction between cancellation and postponement, and notifications matched to their attendance commitment level (going vs interested)
- **Community Organizers**: Need confidence that event updates reach attendees appropriately, ability to reschedule events without spamming attendees, and visibility into notification preferences affecting event participation
- **Platform Organizers**: Need stable notification infrastructure without duplication bugs, scalable preference model for future expansion, and minimal maintenance burden

### Secondary Stakeholders  

- **Developers**: Require clear timezone handling patterns, testable notification logic, and well-documented preference structure for future features
- **Support Staff**: Need clear documentation of notification flows for troubleshooting user reports about missing/duplicate notifications

### Collaborative Decision Points

**Finalized Decisions** (from collaborative review):
1. ✅ **Test coverage first**: Write comprehensive tests before implementation
2. ✅ **Comprehensive approach**: Implement all 9 issues together (not phased)
3. ✅ **Timezone migration strategy**: Default existing events to platform timezone with error logging (no migration failure)
4. ✅ **Preference model**: Simple on/off toggles (no custom timing UI in this phase)
5. ✅ **Digest option**: Deferred to future scope
6. ✅ **Interested attendee reminders**: Granular preferences (users control 24h/1h/start independently)
7. ✅ **Draft status semantics**: Treated as "postponed" (not "cancelled")
8. ✅ **Preference structure**: Flat naming with 6 separate toggles (going_24h, going_1h, going_start, interested_24h, interested_1h, interested_start)
9. ✅ **Preference defaults**: Going attendees default all true; interested attendees default all false
10. ✅ **Privacy notifications**: Deferred to future scope (requires access control design)

## Implementation Priority Matrix

### Single Comprehensive Phase (Estimated: 2-3 development days)

**Priority: HIGH** - Critical timezone bugs and moderate UX gaps affecting all event attendees

1. **Infrastructure Setup** (Step 1-2) - Database migrations, model changes, preference schema
2. **Core Notification Fixes** (Step 3-5) - Debouncing, cancellation/postponement, update categorization  
3. **Timezone & Preference Integration** (Step 6-7) - Timezone-aware scheduling, granular preference filtering
4. **Comprehensive Testing** (Step 8) - Edge cases, preference combinations, timezone transitions
5. **i18n & Documentation** (Step 9) - Translations, system docs, assessment updates

## Detailed Implementation Steps

### Step 1: Add Timezone & Job Tracking Infrastructure

**Files Modified:**
- New migration: `db/migrate/[timestamp]_add_timezone_and_reminder_preferences_to_events.rb`
- Model: `app/models/better_together/event.rb`

**Changes:**

1. **Create migration** adding to `better_together_events` table:
   - `timezone` (string, default: 'UTC', null: false) - Event's timezone for accurate display
   - `reminder_job_ids` (jsonb, default: {}) - Track Sidekiq job IDs for cancellation
   - `reminder_24h_enabled` (boolean, default: true) - Per-event 24h reminder toggle
   - `reminder_1h_enabled` (boolean, default: true) - Per-event 1h reminder toggle
   - `reminder_at_start_enabled` (boolean, default: true) - Per-event at-start reminder toggle

2. **Backfill timezone for existing events**:
   ```ruby
   reversible do |dir|
     dir.up do
       platform = BetterTogether::Platform.host
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
   ```

3. **Add timezone helper methods to Event model**:
   ```ruby
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

**Testing Requirements:**
- Migration runs successfully with existing event data
- Timezone helpers return correct Time objects
- DST transition edge cases (spring forward, fall back)
- International timezone handling (multiple zones in single platform)

---

### Step 2: Expand Person Notification Preferences with Granular Per-Status Toggles

**Files Modified:**
- Model: `app/models/better_together/person.rb`
- View: `app/views/better_together/settings/_preferences.html.erb`
- Locales: `config/locales/better_together/en.yml` (and es, fr, uk)

**Changes:**

1. **Add 8 boolean preferences to Person model** using flat naming in `notification_preferences` store:
   ```ruby
   store_attributes :notification_preferences do
     notify_by_email Boolean, default: true
     show_conversation_details Boolean, default: false
     
     # Event update/cancellation notifications
     event_updates Boolean, default: true
     event_cancellations Boolean, default: true
     
     # Event reminders - Going status (default enabled)
     event_going_reminder_24h Boolean, default: true
     event_going_reminder_1h Boolean, default: true
     event_going_reminder_start Boolean, default: true
     
     # Event reminders - Interested status (default disabled)
     event_interested_reminder_24h Boolean, default: false
     event_interested_reminder_1h Boolean, default: false
     event_interested_reminder_start Boolean, default: false
   end
   ```

2. **Update settings preferences form** with "Event Notifications" section:
   ```erb
   <fieldset class="mb-4">
     <legend class="h5"><%= t('.event_notifications_heading') %></legend>
     
     <div class="form-check mb-2">
       <%= f.check_box :event_updates, class: 'form-check-input' %>
       <%= f.label :event_updates, t('.event_updates_label'), class: 'form-check-label' %>
     </div>
     
     <div class="form-check mb-3">
       <%= f.check_box :event_cancellations, class: 'form-check-input' %>
       <%= f.label :event_cancellations, t('.event_cancellations_label'), class: 'form-check-label' %>
     </div>
     
     <div class="row">
       <div class="col-md-6">
         <h6><%= t('.when_going_heading') %></h6>
         <div class="form-check">
           <%= f.check_box :event_going_reminder_24h, class: 'form-check-input' %>
           <%= f.label :event_going_reminder_24h, t('.reminder_24h_label'), class: 'form-check-label' %>
         </div>
         <div class="form-check">
           <%= f.check_box :event_going_reminder_1h, class: 'form-check-input' %>
           <%= f.label :event_going_reminder_1h, t('.reminder_1h_label'), class: 'form-check-label' %>
         </div>
         <div class="form-check">
           <%= f.check_box :event_going_reminder_start, class: 'form-check-input' %>
           <%= f.label :event_going_reminder_start, t('.reminder_start_label'), class: 'form-check-label' %>
         </div>
       </div>
       
       <div class="col-md-6">
         <h6><%= t('.when_interested_heading') %></h6>
         <div class="form-check">
           <%= f.check_box :event_interested_reminder_24h, class: 'form-check-input' %>
           <%= f.label :event_interested_reminder_24h, t('.reminder_24h_label'), class: 'form-check-label' %>
         </div>
         <div class="form-check">
           <%= f.check_box :event_interested_reminder_1h, class: 'form-check-input' %>
           <%= f.label :event_interested_reminder_1h, t('.reminder_1h_label'), class: 'form-check-label' %>
         </div>
         <div class="form-check">
           <%= f.check_box :event_interested_reminder_start, class: 'form-check-input' %>
           <%= f.label :event_interested_reminder_start, t('.reminder_start_label'), class: 'form-check-label' %>
         </div>
       </div>
     </div>
   </fieldset>
   ```

3. **Add i18n keys** for preference labels and descriptions

**Testing Requirements:**
- Preference getters/setters work correctly
- Form checkboxes reflect current preference values
- Preference updates save successfully
- Default values apply to new users
- All 6 reminder preferences accessible independently

---

### Step 3: Implement Debouncing Service for Duplicate Prevention

**Files Created:**
- Service: `app/services/better_together/event_notification_debouncer.rb`

**Files Modified:**
- Model: `app/models/better_together/event.rb` (callbacks)
- Job: `app/jobs/better_together/event_reminder_scheduler_job.rb`

**Changes:**

1. **Create EventNotificationDebouncer service**:
   ```ruby
   module BetterTogether
     class EventNotificationDebouncer
       DEBOUNCE_WINDOW = 2.minutes
       
       def self.schedule_reminders(event_id)
         redis_key = "event_reminder_debounce:#{event_id}"
         
         # Cancel any pending scheduler jobs
         Sidekiq::ScheduledSet.new.each do |job|
           if job.klass == 'BetterTogether::EventReminderSchedulerJob' && 
              job.args.first.to_s == event_id.to_s
             job.delete
           end
         end
         
         # Check if already scheduled recently
         return if Rails.cache.read(redis_key).present?
         
         # Mark as scheduled
         Rails.cache.write(redis_key, Time.current, expires_in: DEBOUNCE_WINDOW)
         
         # Schedule with delay
         EventReminderSchedulerJob.set(wait: DEBOUNCE_WINDOW)
                                   .perform_later(event_id)
       end
     end
   end
   ```

2. **Update Event callback** to use debouncer:
   ```ruby
   # Replace direct job scheduling
   def schedule_reminder_notifications
     return unless requires_reminder_scheduling?
     EventNotificationDebouncer.schedule_reminders(id)
   end
   ```

3. **Enhance EventReminderSchedulerJob#cancel_existing_reminders**:
   ```ruby
   def cancel_existing_reminders(event)
     # Cancel jobs by stored IDs
     event.reminder_job_ids.each do |reminder_type, job_id|
       scheduled_job = Sidekiq::ScheduledSet.new.find_job(job_id)
       scheduled_job&.delete
     end
     
     # Clear stored job IDs
     event.update_column(:reminder_job_ids, {})
     
     Rails.logger.info "Cancelled existing reminders for event #{event.identifier}"
   end
   ```

4. **Store job IDs after scheduling**:
   ```ruby
   def schedule_24_hour_reminder(event)
     return unless event.reminder_24h_enabled
     
     job = EventReminderJob.set(wait_until: event.local_starts_at.utc - 24.hours)
                           .perform_later(event.id, '24_hours')
     
     store_job_id(event, '24h', job.provider_job_id)
   end
   
   private
   
   def store_job_id(event, type, job_id)
     current_ids = event.reminder_job_ids || {}
     event.update_column(:reminder_job_ids, current_ids.merge(type => job_id))
   end
   ```

**Testing Requirements:**
- Rapid edits (5 updates within 2 minutes) result in only one scheduler job
- Existing reminder jobs cancelled before new ones scheduled
- Job IDs stored and retrievable
- Debounce window expires correctly
- Multiple events don't interfere with each other's debouncing

---

### Step 4: Create Cancellation/Postponement Notification System

**Files Created:**
- Notifier: `app/notifiers/better_together/event_cancellation_notifier.rb`
- Notifier: `app/notifiers/better_together/event_postponement_notifier.rb`
- View: `app/views/better_together/event_mailer/event_cancellation.html.erb`
- View: `app/views/better_together/event_mailer/event_cancellation.text.erb`
- View: `app/views/better_together/event_mailer/event_postponement.html.erb`
- View: `app/views/better_together/event_mailer/event_postponement.text.erb`

**Files Modified:**
- Mailer: `app/mailers/better_together/event_mailer.rb`
- Model: `app/models/better_together/event.rb` (callbacks)

**Changes:**

1. **Create EventCancellationNotifier**:
   ```ruby
   module BetterTogether
     class EventCancellationNotifier < ApplicationNotifier
       deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel',
                  message: :build_message, queue: :notifications do |config|
         config.if = -> { should_notify? }
       end
       
       deliver_by :email, mailer: 'BetterTogether::EventMailer',
                  method: :event_cancellation, params: :email_params,
                  queue: :mailers do |config|
         config.if = -> { send_email_notification? }
       end
       
       validates :record, presence: true
       
       def event
         record
       end
       
       def title
         I18n.t('better_together.notifications.event_cancellation.title',
                event_name: event.name)
       end
       
       def body
         I18n.t('better_together.notifications.event_cancellation.body',
                event_name: event.name,
                event_time: I18n.l(event.starts_at, format: :long))
       end
       
       notification_methods do
         def should_notify?
           event.present? &&
             (!recipient.respond_to?(:notification_preferences) ||
              recipient.notification_preferences.fetch('event_cancellations', true))
         end
         
         def send_email_notification?
           should_notify? &&
             recipient.respond_to?(:email) &&
             recipient.email.present? &&
             recipient.notification_preferences.fetch('notify_by_email', true)
         end
         
         def email_params
           {
             event: event,
             recipient: recipient
           }
         end
       end
     end
   end
   ```

2. **Create EventPostponementNotifier** (similar structure with different copy)

3. **Add mailer methods**:
   ```ruby
   def event_cancellation(event:, recipient:)
     @event = event
     @recipient = recipient
     
     I18n.with_locale(recipient.locale) do
       mail(
         to: recipient.email,
         subject: I18n.t('better_together.event_mailer.event_cancellation.subject',
                        event_name: event.name)
       )
     end
   end
   
   def event_postponement(event:, recipient:)
     @event = event
     @recipient = recipient
     
     I18n.with_locale(recipient.locale) do
       mail(
         to: recipient.email,
         subject: I18n.t('better_together.event_mailer.event_postponement.subject',
                        event_name: event.name)
       )
     end
   end
   ```

4. **Add Event callbacks**:
   ```ruby
   before_destroy :notify_cancellation
   after_update :notify_postponement_if_drafted
   
   private
   
   def notify_cancellation
     return unless attendees.exists?
     
     going_attendees.find_each do |attendance|
       EventCancellationNotifier.with(event: self)
                                .deliver_later(attendance.attendee)
     end
   end
   
   def notify_postponement_if_drafted
     return unless saved_change_to_starts_at? && starts_at.blank? && starts_at_was.present?
     return unless attendees.exists?
     
     going_attendees.find_each do |attendance|
       EventPostponementNotifier.with(event: self)
                                .deliver_later(attendance.attendee)
     end
   end
   
   def going_attendees
     attendees.where(status: 'going')
   end
   ```

5. **Create email templates** with clear distinction between cancellation and postponement

**Testing Requirements:**
- Deleting event triggers cancellation notifications to all going attendees
- Clearing starts_at triggers postponement notifications
- Notifications respect event_cancellations preference
- Email content distinguishes cancellation vs postponement
- Action Cable notifications delivered to online users
- No notifications sent if no attendees

---

### Step 5: Categorize Event Updates by Urgency with Conditional Delays

**Files Modified:**
- Notifier: `app/notifiers/better_together/event_update_notifier.rb`
- View: `app/views/better_together/event_mailer/event_update.html.erb`

**Changes:**

1. **Add change categorization to EventUpdateNotifier**:
   ```ruby
   CRITICAL_ATTRIBUTES = %w[starts_at ends_at].freeze
   IMPORTANT_ATTRIBUTES = %w[name name_en name_es name_fr name_uk location_id].freeze
   MINOR_ATTRIBUTES = %w[description description_en description_es description_fr description_uk].freeze
   
   def urgency
     return :critical if changed_attributes.any? { |attr| CRITICAL_ATTRIBUTES.include?(attr) }
     return :important if changed_attributes.any? { |attr| IMPORTANT_ATTRIBUTES.include?(attr) }
     :minor
   end
   
   # Modify email delivery config
   deliver_by :email, mailer: 'BetterTogether::EventMailer',
              method: :event_update, params: :email_params,
              queue: :mailers do |config|
     config.wait = lambda do |notifier|
       case notifier.urgency
       when :critical then 0
       when :important then 5.minutes
       else 15.minutes
       end
     end
     config.if = -> { send_email_notification? }
   end
   ```

2. **Pass urgency to email params**:
   ```ruby
   def email_params
     {
       event: event,
       changed_attributes: changed_attributes,
       urgency: urgency,
       recipient: recipient
     }
   end
   ```

3. **Update email template with urgency badge**:
   ```erb
   <% badge_class = case urgency
                    when :critical then 'badge bg-danger'
                    when :important then 'badge bg-warning text-dark'
                    else 'badge bg-info'
                    end %>
   
   <div class="mb-3">
     <span class="<%= badge_class %>">
       <%= t(".urgency.#{urgency}") %>
     </span>
   </div>
   ```

**Testing Requirements:**
- Critical changes (starts_at, ends_at) send immediately (0 delay)
- Important changes (name, location) wait 5 minutes
- Minor changes (description) wait 15 minutes
- Urgency badge displays correctly in email
- Mixed changes categorized by highest urgency
- event_updates preference respected

---

### Step 6: Make Reminder Scheduling Timezone-Aware with Per-Status Preference Checking

**Files Modified:**
- Job: `app/jobs/better_together/event_reminder_scheduler_job.rb`
- Job: `app/jobs/better_together/event_reminder_job.rb`
- View: `app/views/better_together/event_mailer/event_reminder.html.erb`

**Changes:**

1. **Update EventReminderSchedulerJob to use timezone-aware calculations**:
   ```ruby
   def schedule_24_hour_reminder(event)
     return unless event.reminder_24h_enabled
     
     # Use event's local time converted to UTC for Sidekiq
     reminder_time = event.local_starts_at - 24.hours
     return if reminder_time < Time.current
     
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

2. **Update EventReminderJob to query attendees separately by status**:
   ```ruby
   def perform(event_id, reminder_type)
     event = Event.find_by(id: event_id)
     return unless event&.starts_at&.future?
     
     # Map reminder type to preference suffix
     preference_suffix = case reminder_type
                        when '24_hours' then '24h'
                        when '1_hour' then '1h'
                        when 'at_start' then 'start'
                        else return
                        end
     
     # Query going attendees with preference check
     going_attendees = event.attendances.includes(:attendee)
                           .where(status: 'going')
                           .select do |attendance|
       pref_key = "event_going_reminder_#{preference_suffix}"
       attendance.attendee.notification_preferences.fetch(pref_key, true)
     end
     
     # Query interested attendees with preference check
     interested_attendees = event.attendances.includes(:attendee)
                                .where(status: 'interested')
                                .select do |attendance|
       pref_key = "event_interested_reminder_#{preference_suffix}"
       attendance.attendee.notification_preferences.fetch(pref_key, false)
     end
     
     # Send notifications
     going_attendees.each do |attendance|
       send_reminder(event, attendance.attendee, reminder_type, 'going')
     end
     
     interested_attendees.each do |attendance|
       send_reminder(event, attendance.attendee, reminder_type, 'interested')
     end
   end
   
   private
   
   def send_reminder(event, recipient, reminder_type, attendee_status)
     EventReminderNotifier.with(
       event: event,
       reminder_type: reminder_type,
       attendee_status: attendee_status,
       recipient_timezone: recipient.time_zone
     ).deliver_later(recipient)
   rescue StandardError => e
     Rails.logger.error("Failed to send reminder for event #{event.id} to #{recipient.id}: #{e.message}")
   end
   ```

3. **Update email template to display both timezones**:
   ```erb
   <% event_time = @event.local_starts_at %>
   <% recipient_time = @event.starts_at_in_zone(@recipient.time_zone) %>
   
   <p class="event-time">
     <strong><%= I18n.l(event_time, format: :long) %> <%= event_time.zone %></strong>
     <% if event_time.zone != recipient_time.zone %>
       <br>
       <small class="text-muted">
         <%= I18n.l(recipient_time, format: :short) %> <%= t('.your_time') %>
       </small>
     <% end %>
   </p>
   ```

**Testing Requirements:**
- Timezone-aware reminder times calculated correctly
- DST transitions handled properly
- Per-event reminder toggles respected
- Going attendees filtered by event_going_reminder_* preferences
- Interested attendees filtered by event_interested_reminder_* preferences
- Both timezones displayed in email when different
- Only one timezone shown when recipient in same zone as event

---

### Step 7: Add Status-Specific Reminder Copy and Preference Filtering

**Files Modified:**
- Notifier: `app/notifiers/better_together/event_reminder_notifier.rb`

**Changes:**

1. **Add attendee_status parameter and preference checking**:
   ```ruby
   validates :record, presence: true
   required_param :reminder_type
   required_param :attendee_status  # 'going' or 'interested'
   
   def should_notify?
     event.present? && check_status_preference
   end
   
   private
   
   def check_status_preference
     return true unless recipient.respond_to?(:notification_preferences)
     
     preference_suffix = case reminder_type
                        when '24_hours' then '24h'
                        when '1_hour' then '1h'
                        when 'at_start' then 'start'
                        else return false
                        end
     
     preference_key = "event_#{attendee_status}_reminder_#{preference_suffix}"
     recipient.notification_preferences.fetch(preference_key, default_for_status)
   end
   
   def default_for_status
     attendee_status == 'going'  # true for going, false for interested
   end
   ```

2. **Update body methods with status-specific copy**:
   ```ruby
   def body_24_hours
     if attendee_status == 'going'
       I18n.t('better_together.notifications.event_reminder.body_24h_going',
              event_name: event.name)
     else
       I18n.t('better_together.notifications.event_reminder.body_24h_interested',
              event_name: event.name)
     end
   end
   
   def body_1_hour
     if attendee_status == 'going'
       I18n.t('better_together.notifications.event_reminder.body_1h_going',
              event_name: event.name)
     else
       I18n.t('better_together.notifications.event_reminder.body_1h_interested',
              event_name: event.name)
     end
   end
   
   def body_at_start
     if attendee_status == 'going'
       I18n.t('better_together.notifications.event_reminder.body_start_going',
              event_name: event.name)
     else
       I18n.t('better_together.notifications.event_reminder.body_start_interested',
              event_name: event.name)
     end
   end
   ```

3. **Add attendee_status to email params**:
   ```ruby
   def email_params
     {
       event: event,
       reminder_type: reminder_type,
       attendee_status: attendee_status,
       recipient: recipient
     }
   end
   ```

**Testing Requirements:**
- Going attendees see "You're attending" copy
- Interested attendees see "You expressed interest - still planning to attend?" copy
- Preference filtering works for all 6 combinations
- Defaults apply correctly (going: all true, interested: all false)
- Missing preference keys handled gracefully

---

### Step 8: Write Comprehensive Test Coverage for Granular Preferences

**Files Created:**
- `spec/services/better_together/event_notification_debouncer_spec.rb`
- `spec/notifiers/better_together/event_cancellation_notifier_spec.rb`
- `spec/notifiers/better_together/event_postponement_notifier_spec.rb`
- `spec/notifiers/better_together/event_update_notifier_spec.rb`

**Files Modified:**
- `spec/models/better_together/event_spec.rb`
- `spec/models/better_together/person_spec.rb`
- `spec/jobs/better_together/event_reminder_scheduler_job_spec.rb`
- `spec/jobs/better_together/event_reminder_job_spec.rb`
- `spec/notifiers/better_together/event_reminder_notifier_spec.rb`
- `spec/mailers/better_together/event_mailer_spec.rb`
- `spec/requests/better_together/settings_controller_spec.rb`

**Test Coverage Requirements:**

1. **Timezone Edge Cases** (`event_spec.rb`):
   - DST spring forward transition (2:00 AM → 3:00 AM)
   - DST fall back transition (2:00 AM → 1:00 AM)
   - International events (NYC timezone viewed by Tokyo user)
   - Timezone helper methods return correct Time objects
   - Migration backfills existing events with platform timezone

2. **Debouncing** (`event_notification_debouncer_spec.rb`):
   - Rapid edits (5 updates within 2 minutes) → 1 scheduler job
   - Debounce window expiration allows next scheduling
   - Multiple events don't interfere with each other
   - Existing scheduler jobs cancelled before new scheduling
   - Redis cache key structure correct

3. **Cancellation/Postponement** (`event_cancellation_notifier_spec.rb`, `event_postponement_notifier_spec.rb`):
   - Deletion triggers cancellation notifications
   - Clearing starts_at triggers postponement notifications
   - No notifications if no attendees
   - Preference filtering (event_cancellations)
   - Email content distinguishes cancellation vs postponement
   - Action Cable delivery to online users

4. **Update Categorization** (`event_update_notifier_spec.rb`):
   - Critical changes (starts_at, ends_at) → immediate delivery
   - Important changes (name, location) → 5-minute delay
   - Minor changes (description) → 15-minute delay
   - Mixed changes use highest urgency
   - Urgency badge in email template
   - Preference filtering (event_updates)

5. **Granular Preferences** (`event_reminder_notifier_spec.rb`):
   - All 6 preference combinations tested:
     - Going user with going_24h enabled → receives 24h reminder
     - Going user with going_24h disabled → no 24h reminder
     - Going user with going_1h enabled → receives 1h reminder
     - Interested user with interested_24h enabled → receives 24h reminder
     - Interested user with interested_24h disabled → no 24h reminder
     - Interested user with interested_1h enabled → receives 1h reminder
   - Status-specific copy ("attending" vs "interested")
   - Anti-spam logic (one email per unread batch)
   - Defaults apply correctly

6. **Timezone-Aware Scheduling** (`event_reminder_scheduler_job_spec.rb`):
   - Reminder times calculated from event.local_starts_at
   - UTC conversion for Sidekiq scheduling
   - Per-event toggles (reminder_24h_enabled, etc.)
   - Job IDs stored correctly
   - Existing jobs cancelled before rescheduling

7. **Per-Status Filtering** (`event_reminder_job_spec.rb`):
   - Going attendees filtered by event_going_reminder_*
   - Interested attendees filtered by event_interested_reminder_*
   - Preference suffix mapping (24_hours → 24h)
   - Graceful handling of missing preferences
   - Individual notification failures don't stop batch

8. **Settings UI** (`settings_controller_spec.rb`):
   - Form displays all 8 event preferences
   - Checkbox updates save correctly
   - Defaults show for new users
   - i18n labels display correctly

**Test Execution Strategy:**
Per project standards:
1. Run individual spec files first: `bin/dc-run bundle exec rspec spec/path/to/file_spec.rb`
2. Verify each passes individually
3. Run all related specs together to check for interactions
4. Only run full suite (`bin/dc-run bin/ci`) after all targeted tests pass (avoids 13-18 minute wait)

---

### Step 9: Add i18n Translations and Update Documentation

**Files Modified:**
- `config/locales/better_together/en.yml`
- `config/locales/better_together/es.yml`
- `config/locales/better_together/fr.yml`
- `config/locales/better_together/uk.yml`
- `docs/systems/events_and_calendar_system.md`
- `docs/assessments/events_and_calendar_system_assessment.md`

**Changes:**

1. **Add comprehensive i18n keys** for all new features:
   ```yaml
   en:
     better_together:
       settings:
         preferences:
           event_notifications_heading: "Event Notifications"
           event_updates_label: "Notify me when events I'm attending are updated"
           event_cancellations_label: "Notify me when events are cancelled or postponed"
           when_going_heading: "When I'm going to an event"
           when_interested_heading: "When I'm interested in an event"
           reminder_24h_label: "24 hours before"
           reminder_1h_label: "1 hour before"
           reminder_start_label: "At event start time"
       
       notifications:
         event_reminder:
           title: "Reminder: %{event_name}"
           body_24h_going: "You're attending '%{event_name}' tomorrow."
           body_24h_interested: "You expressed interest in '%{event_name}' - still planning to attend?"
           body_1h_going: "You're attending '%{event_name}' in 1 hour."
           body_1h_interested: "Reminder: You expressed interest in '%{event_name}' - starts in 1 hour."
           body_start_going: "Your event '%{event_name}' is starting now!"
           body_start_interested: "The event '%{event_name}' you expressed interest in is starting now."
         
         event_cancellation:
           title: "Event Cancelled: %{event_name}"
           body: "The event '%{event_name}' scheduled for %{event_time} has been cancelled."
         
         event_postponement:
           title: "Event Postponed: %{event_name}"
           body: "The event '%{event_name}' has been postponed. A new date will be announced soon."
       
       event_mailer:
         event_cancellation:
           subject: "Event Cancelled: %{event_name}"
           heading: "Event Cancelled"
           message: "We're sorry to inform you that this event has been cancelled."
         
         event_postponement:
           subject: "Event Postponed: %{event_name}"
           heading: "Event Postponed"
           message: "This event has been postponed. We'll let you know once a new date is scheduled."
         
         event_update:
           urgency:
             critical: "Urgent Update"
             important: "Important Update"
             minor: "Update"
         
         event_reminder:
           your_time: "your time"
   ```

2. **Translate all keys to es, fr, uk locales**

3. **Run i18n normalization**: `bin/dc-run bin/i18n normalize`

4. **Update Event Notifications section** in `docs/systems/events_and_calendar_system.md`:
   - Document timezone handling and DST considerations
   - Explain granular 6-preference model (going vs interested, 24h/1h/start)
   - Describe cancellation vs postponement distinction
   - Document update urgency categorization
   - Add troubleshooting section for timezone issues
   - Include preference default rationale

5. **Mark resolved issues** in `docs/assessments/events_and_calendar_system_assessment.md`:
   - ✅ Timezone handling (RESOLVED)
   - ✅ Notification duplication on rapid edits (RESOLVED)
   - ✅ No cancellation notifications (RESOLVED)
   - ✅ Limited granular preference controls (RESOLVED)
   - ✅ Event update notifications not categorized (RESOLVED)
   - ✅ No 'interested' attendee reminders (RESOLVED)
   - ✅ Email batching delay (RESOLVED - urgency-based)
   - ⏳ No privacy change notifications (DEFERRED - future scope)
   - ⏳ No digest option (DEFERRED - future scope)

6. **Document deferred items** as future backlog in assessment:
   - Privacy change notifications (requires access control design)
   - Digest emails (requires cron scheduling infrastructure)
   - Custom reminder timing UI (complex UX, low priority)

**Testing Requirements:**
- All new i18n keys present in all 4 locales
- No missing translation warnings
- i18n health check passes
- Documentation accurately reflects implementation
- Assessment issue statuses updated correctly

---

## Security Considerations

### Pre-Implementation Security Scan
**REQUIRED**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager` before starting implementation

### During Implementation
1. **No unsafe reflection**: All preference keys are hardcoded strings (no user input in constantize)
2. **SQL injection prevention**: All queries use Active Record (no raw SQL strings)
3. **XSS prevention**: All email templates use ERB auto-escaping
4. **Authorization checks**: Notification preferences stored per-user, not controllable by other users
5. **Mass assignment protection**: Person model uses strong parameters for notification_preferences

### Post-Implementation Security Scan
**REQUIRED**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager -c UnsafeReflection,SQL,CrossSiteScripting` after completing each major component

### Privacy Considerations
- Event timezone does not leak user location data (set by event creator, not attendee)
- Notification preferences private to each user
- Email content does not include attendee lists (only event details)
- Cancellation/postponement notifications don't reveal why event changed

---

## Performance Considerations

### Database Queries
- **N+1 Prevention**: Use `includes(:attendee)` when querying attendances
- **Preference Filtering**: Done in Ruby after loading attendees (JSONB query complexity vs memory tradeoff)
- **Job Cancellation**: Iterating Sidekiq::ScheduledSet is O(n) but only runs on event edits (acceptable)

### Background Jobs
- **Queue Separation**: Event notifications use `:notifications` and `:mailers` queues (isolated from other work)
- **Retry Strategy**: Polynomial backoff with 5 max attempts (prevents infinite retries)
- **Debouncing**: 2-minute window reduces job volume during rapid edits by ~80% (estimated)

### Caching
- **Debounce Cache**: Uses Rails.cache (Redis) with 2-minute TTL
- **No additional caching needed**: Event/Person models already cached where appropriate

### Scalability
- **Batch Processing**: Notifications sent one-by-one (allows per-user preference filtering)
- **Job Scheduling**: Each reminder type is separate job (allows granular failure handling)
- **Future Optimization**: If platform scales to 1000+ attendees per event, consider batch notification jobs

---

## Rollback Strategy

### Migration Rollback
1. **Timezone backfill errors**: Logged but don't fail migration (platform continues functioning)
2. **Rollback procedure**:
   ```ruby
   def down
     remove_column :better_together_events, :timezone
     remove_column :better_together_events, :reminder_job_ids
     remove_column :better_together_events, :reminder_24h_enabled
     remove_column :better_together_events, :reminder_1h_enabled
     remove_column :better_together_events, :reminder_at_start_enabled
   end
   ```

### Feature Rollback
1. **Disable debouncing**: Remove `EventNotificationDebouncer.schedule_reminders` call, restore direct job scheduling
2. **Disable new notifiers**: Comment out callbacks in Event model
3. **Revert preferences**: Remove new preference fields from settings form (model changes backward compatible)

### Data Integrity
- **No data loss**: All changes are additive (new columns, new preferences)
- **Existing events**: Continue functioning with default timezone (UTC) if migration partially fails
- **Existing preferences**: Unaffected by new preference additions

---

## Deferred Features (Future Scope)

### Privacy Change Notifications
**Rationale**: Requires careful design of who gets notified (all past attendees? only current?), access control implications (public→private might be intentional hiding), and potential security concerns.

**Future Work**:
- Add privacy to `significant_changes_for_notifications`
- Create EventPrivacyChangeNotifier
- Design notification logic for both directions (public→private, private→public)
- Consider attendee list visibility implications

### Digest Emails
**Rationale**: Requires cron-style scheduling infrastructure, digest preference model (daily/weekly frequency), and significant mailer template work.

**Future Work**:
- Add digest preference to Person model (frequency, time of day)
- Create EventDigestJob (daily cron, weekly cron)
- Create digest email template aggregating upcoming events
- Add "why am I receiving this?" explanation to digest emails

### Custom Reminder Timing UI
**Rationale**: Complex UI for selecting custom reminder times (1 week, 3 days, etc.), per-event configuration storage, and increased UX cognitive load.

**Future Work**:
- Add `custom_reminder_times` JSONB column to events
- Create reminder time picker UI component
- Update scheduler job to handle variable reminder times
- Consider preset options vs free-form time entry

---

## Success Metrics & Validation

### Quantitative Metrics
1. **Duplicate Job Reduction**: Monitor Sidekiq scheduled set size before/after rapid edits (expect ~80% reduction)
2. **Notification Delivery Rate**: Track successful vs failed event notifications (target: >99%)
3. **Preference Adoption**: Measure percentage of users modifying default preferences (baseline metric)
4. **Timezone Accuracy**: Zero reports of incorrect event times after DST transitions

### Qualitative Validation
1. **User Feedback**: Attendees report appropriate reminder frequency and timing
2. **Organizer Feedback**: Event creators confident updates reach attendees without spam
3. **Support Tickets**: Reduction in "I didn't receive a reminder" or "I received too many emails" tickets

### Test Coverage Metrics
- **Target**: 100% code coverage for new features
- **Critical Paths**: All 6 preference combinations covered by specs
- **Edge Cases**: DST transitions, timezone calculations, rapid edits all tested

---

## Implementation Timeline

### Day 1: Infrastructure & Preferences
- Step 1: Migration and timezone helpers (2-3 hours)
- Step 2: Preference model and form (2-3 hours)
- Step 8: Tests for steps 1-2 (1-2 hours)

### Day 2: Core Notification Features
- Step 3: Debouncing service (2-3 hours)
- Step 4: Cancellation/postponement system (3-4 hours)
- Step 5: Update categorization (1-2 hours)
- Step 8: Tests for steps 3-5 (2-3 hours)

### Day 3: Timezone Integration & Finalization
- Step 6: Timezone-aware scheduling (2-3 hours)
- Step 7: Status-specific filtering (1-2 hours)
- Step 8: Tests for steps 6-7 (2-3 hours)
- Step 9: i18n and documentation (1-2 hours)
- Final security scan and full test suite run (1 hour)

**Total Estimated Time**: 2-3 development days (16-24 hours)

---

## Post-Implementation Monitoring

### First Week
- Monitor Sidekiq retry queue for event notification failures
- Check Rails logs for timezone backfill errors
- Review Action Cable delivery success rate
- Track user preference changes in analytics

### First Month
- Measure notification engagement (open rates, click rates)
- Gather user feedback on reminder timing appropriateness
- Identify any edge cases not covered by tests
- Monitor performance impact on background job queues

### Ongoing
- Review support tickets for notification-related issues
- Track preference adoption trends (are users customizing?)
- Monitor for timezone-related bug reports around DST transitions
- Measure duplicate notification reports (should approach zero)

---

## Documentation Updates Required

1. **System Documentation** (`docs/systems/events_and_calendar_system.md`):
   - Update Event Reminder & Notification System section
   - Add timezone handling subsection
   - Document granular preference model with examples
   - Add troubleshooting guide for timezone issues

2. **Assessment Document** (`docs/assessments/events_and_calendar_system_assessment.md`):
   - Mark 9 issues as RESOLVED with implementation references
   - Document 2 issues as DEFERRED with rationale
   - Update recommendations section

3. **End User Documentation** (`docs/end_users/`):
   - Add guide for managing event notification preferences
   - Explain difference between going vs interested reminders
   - Clarify timezone display in event details and emails

4. **Platform Organizer Documentation** (`docs/platform_organizers/`):
   - Explain importance of accurate platform timezone setting
   - Document event postponement vs cancellation semantics
   - Provide guidance on event update communication best practices

---

## Questions & Clarifications Needed

None - All decisions finalized through collaborative review.

---

## Change Log

- **2026-01-15**: Initial implementation plan created
- **2026-01-15**: Updated with granular per-status/per-duration preferences (6 toggles)
- **2026-01-15**: Finalized all collaborative decision points

---

## Approval & Sign-off

**Created By**: AI Assistant (GitHub Copilot)  
**Date**: 2026-01-15  
**Status**: Ready for Collaborative Review  

**Review Checklist**:
- [ ] Stakeholder needs validated
- [ ] Technical approach approved
- [ ] Security considerations reviewed
- [ ] Performance impact acceptable
- [ ] Documentation plan sufficient
- [ ] Timeline realistic
- [ ] Success metrics defined
- [ ] Deferred features documented

**Final Approval**: _Pending collaborative review_
