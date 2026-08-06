# frozen_string_literal: true

module BetterTogether
  module Content
    # Exports cursor-paginated local-origin content for a federated peer connection.
    class FederatedContentExportService # rubocop:todo Metrics/ClassLength
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
          ::BetterTogether::Seeds::Builder.call(
            subject: record,
            profile: :platform_shared,
            context: { connection: connection, sync_depth: connection.sync_depth },
            lane: 'platform_shared',
            persist: false
          ).seed_hash
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
          federation_consent_scoped(
            ::BetterTogether::Post
              .with_translations
              .where(platform: connection.source_platform, privacy: 'public')
              .where(source_id: nil)
              .where.not(published_at: nil)
              .where(::BetterTogether::Post.arel_table[:published_at].lteq(Time.current))
          )
        ).order(updated_at: :asc, id: :asc).limit(limit)
      end

      def exportable_pages
        apply_cursor(
          federation_consent_scoped(
            ::BetterTogether::Page
              .with_translations
              .where(platform: connection.source_platform, privacy: 'public')
              .where(source_id: nil)
              .where.not(published_at: nil)
              .where(::BetterTogether::Page.arel_table[:published_at].lteq(Time.current))
          )
        ).order(updated_at: :asc, id: :asc).limit(limit)
      end

      def exportable_events
        apply_cursor(
          federation_consent_scoped(
            ::BetterTogether::Event
              .with_translations
              .where(platform: connection.source_platform, privacy: 'public')
              .where(source_id: nil)
              .where.not(starts_at: nil)
          )
        ).order(updated_at: :asc, id: :asc).limit(limit)
      end

      # Layers the per-item federation_visibility tri-state, and then any
      # explicit per-connection FederationContentGrant, on top of the
      # creator's global federate_content preference. Precedence (highest to
      # lowest; connection-level allows_content_type? is already checked one
      # layer up in eligible_records):
      #   1. federation_visibility == no_federate -- hard exclude, always wins.
      #   2. An explicit grant for THIS connection -- 'denied' excludes,
      #      'allowed' includes (bypassing the creator's global preference for
      #      this connection only).
      #   3. No grant for this connection -- falls through to:
      #      federate (bypasses creator preference) / platform_default
      #      (creator's global federate_content preference, current behavior).
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def federation_consent_scoped(query)
        model_table = query.klass.quoted_table_name
        scoped = query.where.not(federation_visibility: 'no_federate')

        denied_ids = connection_grant_ids(query.klass, 'denied')
        scoped = scoped.where.not(id: denied_ids) if denied_ids.any?

        return scoped unless query.klass.column_names.include?('creator_id')

        creator_table = ::BetterTogether::Person.quoted_table_name
        scoped_with_creator = scoped.left_joins(:creator)
        # rubocop:disable BetterTogether/NoRawSqlInQueries -- JSONB preference match on optional creator, OR'd with an explicit per-item opt-in override, requires a raw predicate
        preference_scoped = scoped_with_creator.where(
          Arel.sql(
            "#{model_table}.federation_visibility = 'federate' OR " \
            "#{model_table}.creator_id IS NULL OR " \
            "(#{creator_table}.preferences @> '{\"federate_content\": true}')"
          )
        )
        # rubocop:enable BetterTogether/NoRawSqlInQueries

        allowed_ids = connection_grant_ids(query.klass, 'allowed')
        return preference_scoped if allowed_ids.empty?

        preference_scoped.or(scoped_with_creator.where(id: allowed_ids))
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def connection_grant_ids(klass, status)
        ::BetterTogether::FederationContentGrant
          .where(federatable_type: klass.name, platform_connection_id: connection.id, status:)
          .pluck(:federatable_id)
      end

      def apply_cursor(query)
        return query unless cursor

        table = query.klass.quoted_table_name
        # rubocop:disable BetterTogether/NoRawSqlInQueries -- keyset pagination requires a compound OR across (updated_at, id); no Arel equivalent without N+1 risk
        query.where(
          Arel.sql("#{table}.updated_at > ? OR (#{table}.updated_at = ? AND #{table}.id > ?)"),
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
