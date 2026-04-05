# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Imports recipient-scoped private linked seeds into the encrypted local cache.
    class LinkedSeedIngestService # rubocop:disable Metrics/ClassLength
      Result = Struct.new(
        :connection,
        :recipient_person,
        :processed_count,
        :imported_seeds,
        :linked_seeds,
        :unsupported_seeds,
        :planting
      )

      TYPE_SCOPE_MAP = {
        'post' => 'private_posts',
        'page' => 'private_pages',
        'event' => 'private_events'
      }.freeze

      def self.call(connection:, recipient_person:, seeds:)
        new(connection:, recipient_person:, seeds:).call
      end

      def initialize(connection:, recipient_person:, seeds:)
        @connection = connection
        @recipient_person = recipient_person
        @seeds = Array(seeds)
      end

      def call # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        raise ArgumentError, 'connection is required' unless connection
        raise ArgumentError, 'recipient_person is required' unless recipient_person

        planting = create_planting!
        planting.mark_started!

        imported_seeds = []
        linked_seeds = []
        unsupported_seeds = []

        Current.set(platform: connection.target_platform) do
          seeds.each do |seed_data|
            ingest_result = ::BetterTogether::Seeds::Ingest.call(seed_data: seed_data, connection: connection)
            seed = ingest_result.seed_record
            linked_seed = cache_linked_seed(seed)

            if linked_seed.nil?
              unsupported_seeds << seed_data
              next
            end

            imported_seeds << seed
            linked_seeds << linked_seed
          end
        end

        result = Result.new(
          connection:,
          recipient_person:,
          processed_count: linked_seeds.length,
          imported_seeds:,
          linked_seeds:,
          unsupported_seeds:,
          planting:
        )
        planting.mark_completed!(
          'processed_count' => result.processed_count,
          'unsupported_count' => result.unsupported_seeds.length,
          'recipient_person_id' => recipient_person.id
        )
        result
      rescue StandardError => e
        planting&.mark_failed!(e)
        raise
      end

      private

      attr_reader :connection, :recipient_person, :seeds

      def cache_linked_seed(seed) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        return unless seed.private_linked?

        payload = seed.payload_data.with_indifferent_access
        origin = seed.origin.with_indifferent_access
        grant = resolve_grant(origin)
        return unless grant

        required_scope = origin[:required_scope].presence || TYPE_SCOPE_MAP[payload[:type].to_s]
        return unless required_scope.present? && grant.allows_scope?(required_scope)

        cache_result = ::BetterTogether::Seeds::PersonLinkedSeedCacheService.call(
          person_access_grant: grant,
          recipient_person:,
          source_platform: connection.source_platform,
          seed_attributes: {
            identifier: seed.identifier,
            seed_type: payload[:type],
            payload: payload.to_h,
            source_record_type: seed.seedable_type.presence || payload[:type].to_s.classify.prepend('BetterTogether::'),
            source_record_id: payload[:id],
            version: seed.version,
            source_updated_at: payload[:source_updated_at],
            metadata: {
              'lane' => seed.lane,
              'person_access_grant_id' => grant.id,
              'recipient_identifier' => origin[:recipient_identifier]
            }
          }
        )

        cache_result.linked_seed
      end

      def resolve_grant(origin)
        # Scope strictly to this connection — do not fall back to a connection-agnostic
        # lookup, which would allow cross-connection private-seed ingestion.
        grant = ::BetterTogether::PersonAccessGrant.current_active
                                                   .joins(:person_link)
                                                   .find_by(
                                                     id: origin[:person_access_grant_id],
                                                     better_together_person_links: { platform_connection_id: connection.id }
                                                   )
        return unless grant&.active_now?
        return unless grant.grantee_person_id == recipient_person.id

        grant
      end

      def create_planting!
        ::BetterTogether::SeedPlanting.create!(
          planting_type: :federated_tending,
          source: connection.source_platform.resolved_host_url,
          privacy: 'private',
          metadata: {
            'source_platform_id' => connection.source_platform.id,
            'target_platform_id' => connection.target_platform.id,
            'seed_count' => seeds.length,
            'lane' => 'private_linked',
            'recipient_person_id' => recipient_person.id
          }
        )
      end
    end
  end
end
