# frozen_string_literal: true

module BetterTogether
  # Imports or updates a mirrored Event record from a connected remote platform.
  # rubocop:disable Metrics/ClassLength -- Event service requires timezone validation and
  #   event-host management that the simpler Post/Page services do not.
  class FederatedEventMirrorService
    include ::BetterTogether::Federation::MirroredIdentifierResolution

    def initialize(connection:, remote_attributes:, remote_id:, preserve_remote_uuid: false, source_updated_at: nil)
      @connection = connection
      @remote_attributes = remote_attributes.to_h.with_indifferent_access
      @remote_id = remote_id.to_s
      @preserve_remote_uuid = preserve_remote_uuid
      @source_updated_at = source_updated_at
    end

    def call
      authorize_mirroring!

      event = find_or_initialize_event
      assign_attributes(event)
      ensure_source_platform_host(event)
      event.save!
      event
    end

    private

    attr_reader :connection, :remote_attributes, :remote_id, :preserve_remote_uuid, :source_updated_at

    def authorize_mirroring!
      result = ::BetterTogether::Content::FederatedContentAuthorizer.call(
        connection:,
        content_or_type: ::BetterTogether::Event,
        action: :mirror
      )

      return if result.allowed?

      raise ArgumentError, "event mirroring not authorized: #{result.reason}"
    end

    def find_or_initialize_event
      return find_or_initialize_event_by_source_id unless mirror_with_remote_uuid?

      existing_event_with_remote_uuid || existing_event_by_source_id || ::BetterTogether::Event.new(id: remote_id)
    end

    def find_or_initialize_event_by_source_id
      ::BetterTogether::Event.find_or_initialize_by(platform: connection.target_platform, source_id: remote_id)
    end

    def existing_event_with_remote_uuid
      ::BetterTogether::Event.find_by(id: remote_id, platform: connection.target_platform)
    end

    def existing_event_by_source_id
      ::BetterTogether::Event.find_by(platform: connection.target_platform, source_id: remote_id)
    end

    def assign_attributes(event)
      event.assign_attributes(attributes_for(event))
    end

    def attributes_for(event)
      common_event_mirror_attributes(event).merge(
        starts_at: remote_attributes[:starts_at],
        ends_at: remote_attributes[:ends_at],
        duration_minutes: remote_attributes[:duration_minutes],
        registration_url: remote_attributes[:registration_url],
        timezone: normalized_timezone
      )
    end

    def common_event_mirror_attributes(record)
      {
        name: remote_attributes[:name],
        description: remote_attributes[:description],
        identifier: normalized_identifier(record),
        privacy: remote_attributes[:privacy].presence || 'public',
        creator_id: remote_attributes[:creator_id],
        platform: connection.target_platform,
        source_id: effective_preserve_remote_uuid? ? nil : remote_id,
        source_updated_at: normalized_source_updated_at,
        last_synced_at: Time.current
      }
    end

    def ensure_source_platform_host(event)
      return if event.event_hosts.any? { |hosting| hosting.host == connection.source_platform }

      event.event_hosts.build(host: connection.source_platform)
    end

    def normalized_identifier(event)
      # Preserve the existing identifier on a repeat sync — avoids churn on slug/history.
      return event.identifier if event.persisted?

      base = remote_attributes[:identifier].presence ||
             "federated-event-#{remote_id.parameterize.presence || SecureRandom.hex(6)}"
      identifier_or_namespaced(::BetterTogether::Event, base, event.id)
    end

    def normalized_timezone
      timezone = remote_attributes[:timezone].presence || 'UTC'
      TZInfo::Timezone.get(timezone)
      timezone
    rescue TZInfo::InvalidTimezoneIdentifier
      'UTC'
    end

    def normalized_source_updated_at
      return source_updated_at if source_updated_at.present?
      return remote_attributes[:updated_at] if remote_attributes[:updated_at].present?

      Time.current
    end

    def preserve_remote_uuid?
      preserve_remote_uuid
    end

    def effective_preserve_remote_uuid?
      preserve_remote_uuid? && !same_instance_connection?
    end

    def mirror_with_remote_uuid?
      effective_preserve_remote_uuid? && uuid?(remote_id)
    end

    def same_instance_connection?
      connection.source_platform.local_hosted? && connection.target_platform.local_hosted?
    end

    def uuid?(value)
      /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(value.to_s)
    end
  end
end
# rubocop:enable Metrics/ClassLength
