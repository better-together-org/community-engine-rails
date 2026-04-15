# frozen_string_literal: true

module BetterTogether
  class HostDashboardController < ApplicationController # rubocop:todo Style/Documentation, Metrics/ClassLength
    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/AbcSize
    # rubocop:todo Metrics/CyclomaticComplexity
    # rubocop:todo Lint/CopDirectiveSyntax
    def index # rubocop:todo Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
      # rubocop:enable Lint/CopDirectiveSyntax
      authorize [:host_dashboard], :show?, policy_class: HostDashboardPolicy
      build_overview_resources
      build_membership_review_cards
    end

    def safety_review
      authorize [:host_dashboard], :show?, policy_class: HostDashboardPolicy
      authorize ::BetterTogether::Safety::Case, :index?

      build_safety_review_cards
      render :safety_review
    end

    def platform_connection_review
      authorize [:host_dashboard], :show?, policy_class: HostDashboardPolicy
      authorize ::BetterTogether::PlatformConnection, :index?

      build_platform_connection_review_cards
      render :platform_connection_review
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/PerceivedComplexity

    protected

    # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def build_overview_resources
      root_classes = [
        Community, NavigationArea, Page, Platform, Role, ResourcePermission, Category
      ]

      root_classes.each do |klass|
        # sets @klasses and @klass_count instance variables
        set_resource_variables(klass)
      end

      engagement_classes = [
        Post, Comment, CallForInterest
      ]

      engagement_classes.each do |klass|
        # sets @engagement_klasses and @engagement_klass_count instance variables
        set_resource_variables(klass, prefix: 'engagement')
      end

      exchange_classes = [
        Joatu::Offer, Joatu::Request, Joatu::Agreement, Joatu::Category, Joatu::ResponseLink
      ]

      exchange_classes.each do |klass|
        # sets @exchange_klasses and @exchange_klass_count instance variables
        set_resource_variables(klass, prefix: 'exchange')
      end

      event_classes = [
        Event, EventInvitation, EventAttendance, Calendar, CalendarEntry
      ]

      event_classes.each do |klass|
        # sets @klasses and @klass_count instance variables
        set_resource_variables(klass)
      end

      content_classes = [
        Content::Block
      ]

      content_classes.each do |klass|
        # sets @content_klasses and @content_klass_count instance variables
        set_resource_variables(klass, prefix: 'content')
      end

      Content::Block.load_all_subclasses
      content_block_types = Content::Block.descendants.sort_by { |klass| klass.model_name.human }
      content_block_types.each do |klass|
        # sets @content_klasses and @content_klass_count instance variables
        set_resource_variables(klass, prefix: 'content')
      end

      @content_block_type_cards = content_block_types.map do |klass|
        variable_name = klass.model_name.name.demodulize.underscore

        {
          model_class: klass,
          collection: instance_variable_get(:"@content_#{variable_name.pluralize}"),
          count: instance_variable_get(:"@content_#{variable_name}_count"),
          index_url: helpers.content_blocks_path,
          link_index: true,
          link_resources: false
        }
      end

      geography_classes = [
        Geography::Continent, Geography::Country, Geography::State, Geography::Region, Geography::Settlement,
        Geography::Map, Geography::Space
      ]

      geography_classes.each do |klass|
        # sets @geography_klasses and @geography_klass_count instance variables
        set_resource_variables(klass, prefix: 'geography')
      end

      infrastructure_classes = [
        Infrastructure::Building, Infrastructure::Floor, Infrastructure::Room
      ]

      infrastructure_classes.each do |klass|
        # sets @infrastructure_klasses and @infrastructure_klass_count instance variables
        set_resource_variables(klass, prefix: 'infrastructure')
      end

      build_sensitive_directory_cards
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def set_resource_variables(klass, prefix: nil)
      variable_name = klass.model_name.name.demodulize.underscore
      instance_variable_set(:"@#{"#{prefix}_" if prefix}#{variable_name.pluralize}",
                            klass.order(created_at: :desc).limit(3))
      instance_variable_set(:"@#{"#{prefix}_" if prefix}#{variable_name}_count", klass.count)
    end

    def build_sensitive_directory_cards
      @show_people_card = helpers.current_person&.permitted_to?('list_person') || false
      @show_user_card = helpers.current_person&.permitted_to?('manage_platform_users') || false

      set_resource_variables(Person) if @show_people_card
      set_resource_variables(User) if @show_user_card
    end

    def build_membership_review_cards
      communities = sorted_review_communities
      @membership_review_cards = []
      @membership_review_total_open_count = 0
      @membership_review_open_community_count = 0
      return if communities.empty?

      open_requests = open_membership_requests_for(communities)
      requests_by_community = open_requests.group_by(&:target_id)

      @membership_review_total_open_count = open_requests.size
      @membership_review_open_community_count = requests_by_community.count { |_id, requests| requests.any? }
      @membership_review_cards = communities.map { |community| membership_review_card(community, requests_by_community) }
    end

    def sorted_review_communities
      Community.with_translations.to_a.sort_by { |community| community.name.to_s.downcase }
    end

    def open_membership_requests_for(communities)
      BetterTogether::Joatu::MembershipRequest
        .includes(:creator, :target)
        .where(target_type: 'BetterTogether::Community', target_id: communities.map(&:id), status: 'open')
        .order(created_at: :desc)
        .to_a
    end

    def membership_review_card(community, requests_by_community)
      community_requests = requests_by_community.fetch(community.id, [])

      {
        community:,
        open_count: community_requests.size,
        requests_enabled: community.membership_requests_enabled?,
        latest_requests: community_requests.first(3)
      }
    end

    def build_platform_connection_review_cards
      @show_platform_connection_review_section = platform_connection_review_visible?
      reset_platform_connection_review_state
      return unless @show_platform_connection_review_section
      return unless host_platform

      connections = platform_connection_review_connections
      assign_platform_connection_review_counts(connections)
      @platform_connection_review_cards = connections.first(5).map { |connection| platform_connection_review_card(connection) }
    end

    def platform_connection_review_card(connection)
      {
        connection:,
        counterparty: connection.peer_for(host_platform),
        direction: connection.source_platform_id == host_platform.id ? 'outgoing' : 'incoming'
      }
    end

    def host_platform
      @host_platform ||= BetterTogether::Platform.find_by(host: true)
    end

    def platform_connection_review_visible?
      current_person = helpers.current_person
      current_person&.permitted_to?('manage_network_connections') ||
        current_person&.permitted_to?('approve_network_connections') ||
        false
    end

    def reset_platform_connection_review_state
      @platform_connection_review_cards = []
      @platform_connection_review_total_count = 0
      @platform_connection_review_pending_count = 0
      @platform_connection_review_active_count = 0
    end

    def build_safety_review_cards
      @show_safety_review_section = safety_review_visible?
      reset_safety_review_state
      return unless @show_safety_review_section

      report_scope = policy_scope(::BetterTogether::Report)
      @safety_review_snapshot = ::BetterTogether::Safety::LocalReviewSnapshotService.new(
        case_scope: policy_scope(::BetterTogether::Safety::Case),
        report_scope:
      ).call
      @safety_review_report_count = report_scope.count
    end

    def safety_review_visible?
      host_platform.present? && policy(::BetterTogether::Safety::Case).index?
    end

    def reset_safety_review_state
      @safety_review_snapshot = {
        open_cases_count: 0,
        urgent_open_cases_count: 0,
        unassigned_open_cases_count: 0,
        retaliation_risk_open_cases_count: 0,
        repeated_reportables_count: 0,
        content_review_items_count: 0,
        participant_visible_notes_count: 0
      }
      @safety_review_report_count = 0
    end

    def platform_connection_review_connections
      BetterTogether::PlatformConnection
        .includes(:source_platform, :target_platform)
        .for_platform(host_platform)
        .order(updated_at: :desc)
        .to_a
    end

    def assign_platform_connection_review_counts(connections)
      @platform_connection_review_total_count = connections.size
      @platform_connection_review_pending_count = connections.count(&:pending?)
      @platform_connection_review_active_count = connections.count(&:active?)
    end
  end
end
