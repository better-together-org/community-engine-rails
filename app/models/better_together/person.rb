# frozen_string_literal: true

require 'storext'

module BetterTogether
  # A human being
  class Person < ApplicationRecord # rubocop:todo Metrics/ClassLength
    def self.primary_community_delegation_attrs
      []
    end

    include Author
    include Contactable
    include FriendlySlug
    include HostsEvents
    include Identifier
    include Identity
    include Member
    include PrimaryCommunity
    include Privacy
    include Viewable
    include Metrics::Viewable
    include ::Storext.model

    has_community

    # Set up membership associations for platforms and communities
    member joinable_type: 'platform', member_type: 'person', dependent: :destroy
    member joinable_type: 'community', member_type: 'person', dependent: :destroy

    has_many :conversation_participants, dependent: :destroy
    has_many :conversations, through: :conversation_participants
    has_many :created_conversations, as: :creator, class_name: 'BetterTogether::Conversation', dependent: :destroy

    has_many :agreement_participants, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :agreements, through: :agreement_participants

    has_many :person_blocks, foreign_key: :blocker_id, dependent: :destroy, class_name: 'BetterTogether::PersonBlock'
    has_many :blocked_people, through: :person_blocks, source: :blocked
    has_many :blocked_by_person_blocks, foreign_key: :blocked_id, dependent: :destroy, class_name: 'BetterTogether::PersonBlock'
    has_many :blockers, through: :blocked_by_person_blocks, source: :blocker

    has_many :reports_made, foreign_key: :reporter_id, class_name: 'BetterTogether::Report', dependent: :destroy
    has_many :reports_received, as: :reportable, class_name: 'BetterTogether::Report', dependent: :destroy

    has_many :notifications, as: :recipient, dependent: :destroy, class_name: 'Noticed::Notification'
    has_many :notification_mentions, as: :record, dependent: :destroy, class_name: 'Noticed::Event'

    has_many :agreement_participants, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :agreements, through: :agreement_participants

    has_many :person_platform_integrations, dependent: :destroy

    has_many :calendars, foreign_key: :creator_id, class_name: 'BetterTogether::Calendar', dependent: :destroy

    has_many :event_attendances, class_name: 'BetterTogether::EventAttendance', dependent: :destroy
    has_many :event_invitations, class_name: 'BetterTogether::EventInvitation', as: :invitee, dependent: :destroy

    has_one :user_identification,
            lambda {
              where(
                agent_type: 'BetterTogether::User',
                active: true
              )
            },
            as: :identity,
            class_name: 'BetterTogether::Identification'

    # Returns required agreements that this person has not yet accepted
    # @return [ActiveRecord::Relation<BetterTogether::Agreement>] unaccepted required agreements
    def unaccepted_required_agreements
      BetterTogether::ChecksRequiredAgreements.unaccepted_required_agreements(self)
    end

    # Returns true if this person has unaccepted required agreements
    # @return [Boolean]
    def unaccepted_required_agreements?
      BetterTogether::ChecksRequiredAgreements.person_has_unaccepted_required_agreements?(self)
    end

    has_one :user,
            through: :user_identification,
            source: :agent,
            source_type: 'BetterTogether::User'

    member member_type: 'person',
           joinable_type: 'community'

    member member_type: 'person',
           joinable_type: 'platform'

    slugged :identifier, use: %i[slugged mobility], dependent: :delete_all
    store_attributes :preferences do
      locale String, default: I18n.default_locale.to_s
      time_zone String, default: ENV.fetch('APP_TIME_ZONE', 'Newfoundland')
      receive_messages_from_members Boolean, default: false
    end

    store_attributes :notification_preferences do
      notify_by_email Boolean, default: true
      show_conversation_details Boolean, default: false
    end

    # Ensure proper coercion and persistence for preferences store attributes
    def locale=(value)
      prefs = (preferences || {}).dup
      prefs['locale'] = value.nil? ? nil : value.to_s
      self.preferences = prefs
    end

    def time_zone=(value)
      prefs = (preferences || {}).dup
      prefs['time_zone'] = value.nil? ? nil : value.to_s
      self.preferences = prefs
    end

    def receive_messages_from_members=(value)
      prefs = (preferences || {}).dup
      prefs['receive_messages_from_members'] = ActiveModel::Type::Boolean.new.cast(value)
      self.preferences = prefs
    end

    # Ensure boolean coercion for form submissions ("0"/"1"), regardless of underlying store casting
    def notify_by_email=(value)
      prefs = (notification_preferences || {}).dup
      prefs['notify_by_email'] = ActiveModel::Type::Boolean.new.cast(value)
      self.notification_preferences = prefs
    end

    def show_conversation_details=(value)
      prefs = (notification_preferences || {}).dup
      prefs['show_conversation_details'] = ActiveModel::Type::Boolean.new.cast(value)
      self.notification_preferences = prefs
    end

    validates :name,
              presence: true
    validates :locale,
              inclusion: { in: -> { I18n.available_locales.map(&:to_s) } },
              allow_nil: true

    translates :description_html, backend: :action_text

    # Return email from user if available, otherwise from contact details
    def email
      return user.email if user&.email.present?

      # Fallback to primary email address from contact details
      email_addresses.find(&:primary_flag)&.email
    end

    has_one_attached :profile_image
    has_one_attached :cover_image

    # Resize the profile image before rendering (non-blocking version)
    def profile_image_variant(size)
      return profile_image.variant(resize_to_fill: [size, size]) unless Rails.env.production?

      # In production, avoid blocking .processed calls
      profile_image.variant(resize_to_fill: [size, size])
    end

    # Get optimized profile image variant without blocking rendering
    def profile_image_url(size: 300)
      return nil unless profile_image.attached?

      variant = profile_image.variant(resize_to_fill: [size, size])

      # For better performance, use Rails URL helpers for variant
      Rails.application.routes.url_helpers.url_for(variant)
    rescue ActiveStorage::FileNotFoundError
      nil
    end

    # Resize the cover image to specific dimensions
    def cover_image_variant(width, height)
      cover_image.variant(resize_to_fill: [width, height]).processed
    end

    def description_html(locale: I18n.locale)
      super || description
    end

    def valid_event_host_ids
      [id] + member_communities.pluck(:id)
    end

    def handle
      identifier
    end

    def select_option_title
      "#{name} - @#{handle}"
    end

    def to_s
      name
    end

    def primary_community_extra_attrs
      { protected: true }
    end

    def primary_calendar
      @primary_calendar ||= calendars.find_or_create_by(
        identifier: "#{identifier}-personal-calendar",
        community:
      ) do |calendar|
        calendar.name = I18n.t('better_together.calendars.personal_calendar_name', name: name)
        calendar.privacy = 'private'
        calendar.protected = true
      end
    end

    def after_record_created
      return unless community

      community.reload
      community.update!(creator_id: id)
    end

    # Returns all events relevant to this person's calendar view
    # Combines events they're going to, created, and interested in
    def all_calendar_events # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @all_calendar_events ||= begin
        # Build a single query to get all relevant events with proper includes
        event_ids = Set.new

        # Get event IDs from calendar entries (going events)
        calendar_event_ids = primary_calendar.calendar_entries.pluck(:event_id)
        event_ids.merge(calendar_event_ids)

        # Get event IDs from attendances (interested events)
        attendance_event_ids = event_attendances.pluck(:event_id)
        event_ids.merge(attendance_event_ids)

        # Get event IDs from created events
        created_event_ids = Event.where(creator_id: id).pluck(:id)
        event_ids.merge(created_event_ids)

        # Single query to fetch all events with necessary includes
        if event_ids.any?
          Event.includes(:string_translations)
               .where(id: event_ids.to_a)
               .to_a
        else
          []
        end
      end
    end

    # Determines the relationship type for an event
    # Returns: :going, :created, :interested, or :calendar
    def event_relationship_for(event)
      # Check if they created it first (highest priority)
      return :created if event.creator_id == id

      # Use memoized attendances to avoid N+1 queries
      @_event_attendances_by_event_id ||= event_attendances.index_by(&:event_id)
      attendance = @_event_attendances_by_event_id[event.id]

      return attendance.status.to_sym if attendance

      # Check if it's in their calendar (for events added directly to calendar)
      @_calendar_event_ids ||= Set.new(primary_calendar.calendar_entries.pluck(:event_id))
      return :going if @_calendar_event_ids.include?(event.id)

      :calendar # Default for calendar events
    end

    # Preloads associations needed for calendar display to avoid N+1 queries
    def preload_calendar_associations!
      # Preload event attendances
      event_attendances.includes(:event).load

      # Preload calendar entries
      primary_calendar.calendar_entries.includes(:event).load

      # Reset memoized variables
      @all_calendar_events = nil
      @_event_attendances_by_event_id = nil
      @_calendar_event_ids = nil

      self
    end

    include ::BetterTogether::RemoveableAttachment
  end
end
