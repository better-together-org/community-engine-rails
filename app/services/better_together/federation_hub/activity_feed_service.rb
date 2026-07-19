# frozen_string_literal: true

module BetterTogether
  module FederationHub
    # Kaminari-paginated federation activity feed. Queries BetterTogether::Activity
    # directly rather than the generic ActivityPolicy::Scope, which hard-filters
    # to public-privacy activities — wrong for connection audit activity, which
    # must stay restricted to permission-holders. Visibility is instead gated by
    # the caller (FederationHubController) via include_admin_feed:.
    class ActivityFeedService
      DEFAULT_PER_PAGE = 25
      CONNECTION_TRACKABLE_TYPE = 'BetterTogether::PlatformConnection'

      def self.call(person:, include_admin_feed: false, filters: {}, page: nil, per_page: DEFAULT_PER_PAGE)
        new(person:, include_admin_feed:, filters:, page:, per_page:).call
      end

      def initialize(person:, include_admin_feed: false, filters: {}, page: nil, per_page: DEFAULT_PER_PAGE)
        @person = person
        @include_admin_feed = include_admin_feed
        @filters = (filters || {}).symbolize_keys
        @page = page
        @per_page = per_page
      end

      def call
        relation = base_relation
        relation = filter_by_content_type(relation)
        relation = filter_by_direction(relation)
        relation = filter_by_platform(relation)
        relation.order(created_at: :desc).page(page).per(per_page)
      end

      private

      attr_reader :person, :include_admin_feed, :filters, :page, :per_page

      def base_relation
        scope = ::BetterTogether::Activity.includes(:trackable, :owner)
        personal = personal_relation(scope)

        return personal unless include_admin_feed

        personal.or(scope.where(trackable_type: CONNECTION_TRACKABLE_TYPE))
      end

      def personal_relation(scope)
        return scope.none unless person

        scope.where(
          owner_type: 'BetterTogether::Person',
          owner_id: person.id,
          trackable_type: federatable_trackable_types
        )
      end

      # Discovers content classes dynamically via Federatable.included_in_models
      # instead of a hardcoded allowlist, matching PersonalContentSummaryService.
      def federatable_trackable_types
        ::BetterTogether::Federatable.included_in_models.map(&:name)
      end

      def filter_by_content_type(relation)
        type = filters[:content_type].presence
        return relation unless type

        klass_name = federatable_trackable_types.find { |name| name.demodulize.underscore == type.to_s }
        return relation.none unless klass_name

        relation.where(trackable_type: klass_name)
      end

      # Direction only applies to connection activity — restricts the feed to
      # connections where the host platform is the source (outgoing) or the
      # target (incoming), expressed as a subquery so pagination stays SQL-only.
      def filter_by_direction(relation)
        direction = filters[:direction].presence
        return relation unless direction

        host_platform = ::BetterTogether::Platform.find_by(host: true)
        return relation.where(trackable_type: CONNECTION_TRACKABLE_TYPE) unless host_platform

        column = direction == 'outgoing' ? :source_platform_id : :target_platform_id
        connection_ids = ::BetterTogether::PlatformConnection.where(column => host_platform.id).select(:id)
        relation.where(trackable_type: CONNECTION_TRACKABLE_TYPE, trackable_id: connection_ids)
      end

      def filter_by_platform(relation)
        platform_id = filters[:platform_id].presence
        return relation unless platform_id

        relation.where(platform_id:)
      end
    end
  end
end
