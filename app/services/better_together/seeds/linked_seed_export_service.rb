# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Exports recipient-scoped private seeds for an active person access grant.
    class LinkedSeedExportService
      DEFAULT_LIMIT = 50

      Result = Struct.new(
        :connection,
        :person_access_grant,
        :seeds,
        :next_cursor,
        keyword_init: true
      )

      TYPE_SCOPE_MAP = {
        'post' => 'private_posts',
        'page' => 'private_pages',
        'event' => 'private_events'
      }.freeze

      def self.call(connection:, recipient_identifier:, cursor: nil, limit: DEFAULT_LIMIT)
        new(connection:, recipient_identifier:, cursor:, limit:).call
      end

      def initialize(connection:, recipient_identifier:, cursor: nil, limit: DEFAULT_LIMIT)
        @connection = connection
        @recipient_identifier = recipient_identifier.to_s
        @cursor = cursor
        @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
      end

      def call
        raise ArgumentError, 'connection is required' unless connection
        raise ArgumentError, 'recipient_identifier is required' if recipient_identifier.blank?

        grant = active_access_grant
        return Result.new(connection:, person_access_grant: nil, seeds: [], next_cursor: nil) unless grant

        visible_records = exportable_records_for(grant)
        start_index = normalized_cursor
        batch = visible_records.drop(start_index).first(limit)
        next_cursor = batch.length == limit ? (start_index + batch.length).to_s : nil

        Result.new(
          connection:,
          person_access_grant: grant,
          seeds: batch.map { |record| build_seed(record, grant) },
          next_cursor:
        )
      end

      private

      attr_reader :connection, :recipient_identifier, :cursor, :limit

      def active_access_grant
        ::BetterTogether::PersonAccessGrant.active
                                           .joins(:person_link)
                                           .where(better_together_person_links: { platform_connection_id: connection.id })
                                           .find do |grant|
          next false unless grant.active_now?

          grant.remote_grantee_identifier.to_s == recipient_identifier ||
            grant.grantee_person&.identifier.to_s == recipient_identifier
        end
      end

      def exportable_records_for(grant)
        records = []
        records.concat(private_posts_for(grant)) if grant.allow_private_posts?
        records.concat(private_pages_for(grant)) if grant.allow_private_pages?
        records.concat(private_events_for(grant)) if grant.allow_private_events?

        records.sort_by(&:updated_at).reverse
      end

      def private_posts_for(grant)
        ::BetterTogether::Post.with_creator(grant.grantor_person).privacy_private.to_a
      end

      def private_pages_for(grant)
        ::BetterTogether::Page.with_creator(grant.grantor_person).privacy_private.to_a
      end

      def private_events_for(grant)
        ::BetterTogether::Event.with_creator(grant.grantor_person).privacy_private.to_a
      end

      def build_seed(record, grant)
        ::BetterTogether::Seeds::FederatedSeedBuilder.call(
          record:,
          connection:,
          lane: 'private_linked',
          origin_metadata: {
            person_access_grant_id: grant.id,
            recipient_identifier: recipient_identifier,
            required_scope: TYPE_SCOPE_MAP.fetch(serialized_type_for(record))
          }
        )
      end

      def serialized_type_for(record)
        case record
        when ::BetterTogether::Post then 'post'
        when ::BetterTogether::Page then 'page'
        when ::BetterTogether::Event then 'event'
        else
          raise ArgumentError, "unsupported record type: #{record.class.name}"
        end
      end

      def normalized_cursor
        value = cursor.to_i
        value.negative? ? 0 : value
      end
    end
  end
end
