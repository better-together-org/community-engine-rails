# frozen_string_literal: true

module BetterTogether
  # Resolves which audience should receive a given feedback action for a record.
  class FeedbackRoutingResolver
    Result = Struct.new(
      :action_kind,
      :route,
      :visibility,
      :reviewer_permission,
      :review_target,
      :owner_person
    ) do
      def safety_route?
        route == :platform_safety_team
      end

      def steward_route?
        !safety_route?
      end
    end

    def self.call(record, action_kind:)
      new(record, action_kind:).call
    end

    def initialize(record, action_kind:)
      @record = record
      @action_kind = action_kind.to_sym
    end

    def call
      return safety_route_result if action_kind == :report_safety_issue

      steward_route_result
    end

    private

    attr_reader :record, :action_kind

    def safety_route_result
      Result.new(
        action_kind:,
        route: :platform_safety_team,
        visibility: :private_to_reporter_and_platform_safety,
        reviewer_permission: 'manage_platform_safety',
        review_target: resolved_platform || resolved_community || record,
        owner_person: resolved_owner
      )
    end

    def steward_route_result
      route = steward_route

      Result.new(
        action_kind:,
        route:,
        visibility: :private_to_submitter_and_stewards,
        reviewer_permission: route == :community_stewards ? 'manage_community_content' : 'manage_platform',
        review_target: route == :community_stewards ? resolved_community : (resolved_platform || record),
        owner_person: resolved_owner
      )
    end

    def steward_route
      return :profile_stewards if record.is_a?(BetterTogether::Person)
      return :community_stewards if resolved_community.present?

      :platform_content_stewards
    end

    def resolved_community
      return record.community if record.respond_to?(:community) && record.community.present?
      return record if record.is_a?(BetterTogether::Community)
      return resolved_block_page.community if record.is_a?(BetterTogether::Content::Block) && resolved_block_page.present?

      nil
    end

    def resolved_platform
      direct_platform = record_platform
      return direct_platform if direct_platform.present?

      community_platform = community_primary_platform
      return community_platform if community_platform.present?

      return block_page_platform if block_page_platform.present?

      nil
    end

    def resolved_owner
      return record if record.is_a?(BetterTogether::Person)
      return record.creator if record.respond_to?(:creator) && record.creator.present?

      nil
    end

    def resolved_block_page
      @resolved_block_page ||= record.pages.first if record.is_a?(BetterTogether::Content::Block)
    end

    def record_platform
      return unless record.respond_to?(:platform)

      record.platform
    end

    def community_primary_platform
      return unless record.is_a?(BetterTogether::Community)

      record.primary_platform
    end

    def block_page_platform
      return unless record.is_a?(BetterTogether::Content::Block) && resolved_block_page.present?

      resolved_block_page.platform
    end
  end
end
