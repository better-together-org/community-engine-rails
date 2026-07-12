# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the Event class for JSONAPI
      class EventResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Event'

        # Translated attributes
        attributes :name, :description

        # Standard attributes
        attributes :slug, :identifier, :privacy,
                   :starts_at, :ends_at, :duration_minutes,
                   :registration_url, :timezone

        # Virtual attributes for attachments
        attribute :cover_image_url

        # Virtual attributes for computed fields
        attribute :local_starts_at
        attribute :local_ends_at
        attribute :timezone_display

        # Relationships
        has_one :creator, class_name: 'Person'
        has_many :attendees, class_name: 'Person'

        # Assign creator from the JWT/OAuth-authenticated API user when the request doesn't
        # explicitly supply one. Event#set_host builds an EventHost from `creator` before
        # validation, so without this the API create path fails with
        # "event_hosts.host - must exist" (mirrors MembershipRequestResource's pattern).
        def self.create(context)
          resource = super
          resource._model.creator ||= context[:current_user]&.person
          resource
        end

        # Filters
        filter :privacy
        filter :creator_id
        filter :timezone

        # Custom filter for upcoming events
        filter :scope, apply: lambda { |records, value, _options|
          case value.first
          when 'upcoming'
            records.upcoming
          when 'past'
            records.past
          when 'ongoing'
            records.ongoing
          when 'draft'
            records.draft
          when 'scheduled'
            records.scheduled
          else
            records
          end
        }

        # Override records to avoid polymorphic eager loading issues
        # EventPolicy::Scope#resolve includes categorizations with polymorphic :category
        # which ActiveRecord cannot eagerly load via includes(). We apply an API-specific
        # scope that provides the same authorization without the problematic includes.
        def self.records(options = {}) # rubocop:disable Metrics/AbcSize
          context = options[:context]
          context[:policy_used]&.call

          events = BetterTogether::Event.includes(:string_translations, :creator)
          person = context&.dig(:current_person)

          if person
            events.where(person_visibility_query(events, person)).order(starts_at: :desc, created_at: :desc)
          else
            events.where(privacy: 'public')
                  .where.not(starts_at: nil)
                  .where.not(status: 'draft')
                  .order(starts_at: :desc, created_at: :desc)
          end
        end

        # Mirrors EventPolicy::Scope's draft-visibility rule (creators, hosts,
        # attendees, invitees, and platform event managers can see draft events
        # they're connected to) without EventPolicy::Scope#resolve's polymorphic
        # categorization includes, which #records avoids for the eager-loading
        # reasons noted above. Otherwise a public event with status: 'draft'
        # and a future starts_at is hidden from the HTML index but still
        # returned here to any authenticated person.
        def self.person_visibility_query(events, person) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
          table = events.arel_table
          base = table[:privacy].eq('public').or(table[:creator_id].eq(person.id))

          return base if platform_event_manager?(person)

          query = base.and(table[:status].not_eq('draft')).or(table[:creator_id].eq(person.id))

          connected_event_ids = connected_event_ids_for(person)
          query = query.or(table[:privacy].eq('public').and(table[:id].in(connected_event_ids))) if connected_event_ids.any?

          query
        end

        def self.connected_event_ids_for(person)
          ids = ::BetterTogether::EventHost.where(host_id: person.valid_event_host_ids).pluck(:event_id)
          ids += person.event_attendances.pluck(:event_id)
          ids += person.event_invitations.pluck(:invitable_id)
          ids.uniq
        end

        def self.platform_event_manager?(person)
          person.permitted_to?('manage_platform_settings') || person.permitted_to?('manage_platform')
        end

        # Custom attribute methods
        def cover_image_url
          attachment_url(:cover_image)
        end

        def local_starts_at
          @model.local_starts_at&.iso8601
        end

        def local_ends_at
          @model.local_ends_at&.iso8601
        end

        def timezone_display
          @model.timezone_display
        end

        # Creatable and updatable fields
        def self.creatable_fields(context)
          super - %i[slug local_starts_at local_ends_at timezone_display cover_image_url]
        end

        def self.updatable_fields(context)
          creatable_fields(context)
        end
      end
    end
  end
end
