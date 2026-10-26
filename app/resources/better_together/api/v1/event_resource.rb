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

        # Publisher inputs: hosts (EventHosting), lifecycle status, a base64 cover image and blocks appended to the
        # description (BlockAttachments). The write-only ones are never returned.
        attributes :hosts, :status, :cover_image_data, :cover_image_filename, :attachment_block_ids

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
        # which ActiveRecord cannot eagerly load via includes(). We apply the same
        # privacy/status/connection predicate (EventPolicy::Scope#permitted_query,
        # made public for exactly this reuse) directly, instead of a bare .includes(),
        # so this resource can never drift from the HTML index's authorization rule.
        def self.records(options = {})
          context = options[:context]
          context[:policy_used]&.call

          policy_scope = ::BetterTogether::EventPolicy::Scope.new(context&.dig(:current_user), ::BetterTogether::Event)

          BetterTogether::Event.includes(:string_translations, :creator)
                               .where(policy_scope.permitted_query)
                               .order(starts_at: :desc, created_at: :desc)
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

        def fetchable_fields
          super - %i[cover_image_data cover_image_filename attachment_block_ids]
        end

        # As in the event form, a host must be the person or a community they belong to; platform managers may
        # name any host.
        def hosts=(value)
          raise JSONAPI::Exceptions::InvalidFieldValue.new(:hosts, value) unless may_host?(value)

          @model.hosts = value
        end

        def status=(value)
          unless BetterTogether::Event.statuses.key?(value.to_s)
            raise JSONAPI::Exceptions::InvalidFieldValue.new(:status, value)
          end

          @model.status = value
        end

        # Creatable and updatable fields
        def self.creatable_fields(context)
          super - %i[slug local_starts_at local_ends_at timezone_display cover_image_url]
        end

        def self.updatable_fields(context)
          creatable_fields(context)
        end

        private

        def may_host?(value)
          person = context[:current_user]&.person
          return false unless person
          return true if person.permitted_to?('manage_platform')

          allowed = person.valid_event_host_ids.map(&:to_s)
          parsed_host_ids(value).all? { |id| allowed.include?(id) }
        end

        def parsed_host_ids(value)
          value = JSON.parse(value) if value.is_a?(String)
          Array(value).map { |spec| spec.to_h.with_indifferent_access[:host_id].to_s }
        rescue JSON::ParserError
          []
        end
      end
    end
  end
end
