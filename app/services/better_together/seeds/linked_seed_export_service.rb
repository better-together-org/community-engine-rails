# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Exports recipient-scoped private seeds for an active person access grant.
    # rubocop:disable Metrics/ClassLength
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
        return empty_result unless grant

        batch, next_cursor = paginate_records(exportable_records_for(grant))

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
        base_scope = ::BetterTogether::PersonAccessGrant.current_active.for_connection(connection)
        base_scope.find_by(remote_grantee_identifier: recipient_identifier) ||
          base_scope.joins(:grantee_person)
                    .find_by(better_together_people: { identifier: recipient_identifier })
      end

      def exportable_records_for(grant)
        records = []
        # Load only as many records as needed: offset + page size.
        # This bounds memory per request regardless of page depth.
        max = [normalized_cursor + limit, 500].min
        records.concat(private_posts_for(grant, max)) if grant.allow_private_posts?
        records.concat(private_pages_for(grant, max)) if grant.allow_private_pages?
        records.concat(private_events_for(grant, max)) if grant.allow_private_events?

        records.sort_by(&:updated_at).reverse
      end

      def private_posts_for(grant, max)
        ::BetterTogether::Post.with_creator(grant.grantor_person)
                              .where(platform_id: connection.source_platform_id)
                              .privacy_private
                              .order(updated_at: :desc)
                              .limit(max)
                              .to_a
      end

      def private_pages_for(grant, max)
        ::BetterTogether::Page.with_creator(grant.grantor_person)
                              .where(platform_id: connection.source_platform_id)
                              .privacy_private
                              .order(updated_at: :desc)
                              .limit(max)
                              .to_a
      end

      def private_events_for(grant, max)
        ::BetterTogether::Event.with_creator(grant.grantor_person)
                               .where(platform_id: connection.source_platform_id)
                               .privacy_private
                               .order(updated_at: :desc)
                               .limit(max)
                               .to_a
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

      def empty_result
        Result.new(connection:, person_access_grant: nil, seeds: [], next_cursor: nil)
      end

      def paginate_records(records)
        start_index = normalized_cursor
        batch = records.drop(start_index).first(limit)
        next_cursor = batch.length == limit ? (start_index + batch.length).to_s : nil
        [batch, next_cursor]
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
