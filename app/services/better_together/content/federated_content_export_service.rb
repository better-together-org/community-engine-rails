# frozen_string_literal: true

module BetterTogether
  module Content
    # Exports cursor-paginated local-origin content for a federated peer connection.
    class FederatedContentExportService
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 200

      Result = Struct.new(
        :connection,
        :seeds,
        :next_cursor
      ) do
        def items
          seeds
        end
      end

      def self.call(connection:, cursor: nil, limit: DEFAULT_LIMIT)
        new(connection:, cursor:, limit:).call
      end

      def initialize(connection:, cursor: nil, limit: DEFAULT_LIMIT)
        @connection = connection
        @cursor = parse_cursor(cursor)
        @limit = normalize_limit(limit)
      end

      def call
        Result.new(
          connection:,
          seeds: serialized_seeds,
          next_cursor: next_cursor
        )
      end

      private

      attr_reader :connection, :cursor, :limit

      def serialized_seeds
        @serialized_seeds ||= selected_records.map do |record|
          ::BetterTogether::Seeds::FederatedSeedBuilder.call(
            record:,
            connection:,
            lane: 'platform_shared'
          )
        end
      end

      def selected_records
        @selected_records ||= eligible_records.sort_by { |record| [record.updated_at, record.id] }.first(limit)
      end

      def eligible_records
        records = []
        records.concat(exportable_posts.to_a) if connection.allows_content_type?('posts')
        records.concat(exportable_pages.to_a) if connection.allows_content_type?('pages')
        records.concat(exportable_events.to_a) if connection.allows_content_type?('events')
        records
      end

      def exportable_posts
        apply_cursor(
          ::BetterTogether::Post.where(platform: connection.source_platform, privacy: 'public')
                                .where(source_id: nil)
                                .where.not(published_at: nil)
                                .where(::BetterTogether::Post.arel_table[:published_at].lteq(Time.current))
        ).order(updated_at: :asc, id: :asc).limit(limit)
      end

      def exportable_pages
        apply_cursor(
          ::BetterTogether::Page.where(platform: connection.source_platform, privacy: 'public')
                                .where(source_id: nil)
                                .where.not(published_at: nil)
                                .where(::BetterTogether::Page.arel_table[:published_at].lteq(Time.current))
        ).order(updated_at: :asc, id: :asc).limit(limit)
      end

      def exportable_events
        apply_cursor(
          ::BetterTogether::Event.where(platform: connection.source_platform, privacy: 'public')
                                 .where(source_id: nil)
                                 .where.not(starts_at: nil)
        ).order(updated_at: :asc, id: :asc).limit(limit)
      end

      def apply_cursor(query)
        return query unless cursor

        # rubocop:disable BetterTogether/NoRawSqlInQueries -- keyset pagination requires a compound OR across (updated_at, id); no Arel equivalent without N+1 risk
        query.where(
          Arel.sql('updated_at > ? OR (updated_at = ? AND id > ?)'),
          cursor[:updated_at], cursor[:updated_at], cursor[:id]
        )
        # rubocop:enable BetterTogether/NoRawSqlInQueries
      end

      def next_cursor
        last_record = selected_records.last
        return if last_record.nil?

        [last_record.updated_at.iso8601, last_record.id].join('|')
      end

      def parse_cursor(cursor_value)
        return if cursor_value.blank?

        updated_at, id = cursor_value.to_s.split('|', 2)
        return if updated_at.blank? || id.blank?

        { updated_at: Time.zone.parse(updated_at), id: id }
      rescue ArgumentError
        nil
      end

      def normalize_limit(value)
        requested = value.to_i
        requested = DEFAULT_LIMIT if requested <= 0
        [requested, MAX_LIMIT].min
      end
    end
  end
end
