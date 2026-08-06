# frozen_string_literal: true

module BetterTogether
  class CommunityPolicy < PlatformRecordPolicy # rubocop:todo Style/Documentation, Metrics/ClassLength
    include SelfServicePublishablePolicy

    # Permission identifiers that satisfy #update? at the record level (mirrors
    # can_manage_community? + the direct update_community check below). Kept as a
    # constant so .manageable_community_ids can express the same rule as one SQL
    # query instead of N per-record permitted_to? calls.
    UPDATE_PERMISSION_IDENTIFIERS = %w[manage_community_settings manage_community_members update_community].freeze

    class << self
      # Batched equivalent of calling `policy(community).update?` once per candidate
      # community — avoids the N+1 query pattern of doing that in a loop. Must be kept
      # in sync by hand with #update?/#can_manage_community? below; this RBAC system
      # has no single source of truth that generates both the Ruby and SQL forms.
      def manageable_community_ids(agent, community_ids)
        community_ids = Array(community_ids)
        return [] if agent.blank? || community_ids.empty?
        return community_ids if platform_manager_agent?(agent)

        BetterTogether::PersonCommunityMembership
          .active
          .where(member: agent, joinable_id: community_ids)
          .joins(role: :resource_permissions)
          .where(better_together_resource_permissions: { identifier: UPDATE_PERMISSION_IDENTIFIERS })
          .distinct
          .pluck(:joinable_id)
      end

      def platform_manager_agent?(agent)
        agent.permitted_to?('manage_platform_settings') || agent.permitted_to?('manage_platform')
      end
    end

    def index?
      true # Allow all users to view community index (scope filters appropriately)
    end

    def show?
      public_or_member_scoped_community?(record) ||
        member_of_community? ||
        creator_of_community? ||
        can_manage_community? ||
        invitation? ||
        valid_invitation_token?
    end

    def create?
      return false unless user.present?

      # Platform managers can always create communities
      return true if platform_manager?

      # All other authenticated users must have accepted the community creation agreement
      return false unless agent.present?

      accepted_agreement?(ChecksRequiredAgreements::COMMUNITY_CREATION_AGREEMENT_IDENTIFIER)
    end

    def new?
      create?
    end

    def update?
      user.present? && (can_manage_community? || permitted_to?('update_community', record))
    end

    def manage_integrations?
      update?
    end

    def manage_merchant_account?
      user.present? &&
        (
          permitted_to?('manage_community_settings', record) ||
          permitted_to?('manage_platform_settings') ||
          permitted_to?('manage_platform')
        )
    end

    def create_events?
      return false unless user.present? && agent.present?

      # Platform managers always have event management authority
      return true if permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')

      # Explicit event management permission for this community
      return true if permitted_to?('manage_community_events', record)

      # Any active member of this community can host events on its behalf.
      # This preserves existing venue/community event management behavior (e.g. NL Venues).
      record.persisted? && agent.valid_event_host_ids.include?(record.id)
    end

    def view_members?
      return false unless user.present?

      member_of_community? ||
        creator_of_community? ||
        permitted_to?('manage_community_members', record) ||
        can_manage_community?
    end

    def manage_roles?
      return false unless user.present?

      permitted_to?('manage_community_roles', record) || can_manage_community?
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && !record.protected? && !record.host? &&
        (can_manage_community? || permitted_to?('destroy_community', record))
    end

    def invitation?
      return false unless agent.present?

      # Check if the current person has an invitation to this community
      BetterTogether::CommunityInvitation.exists?(
        invitable: record,
        invitee: agent
      )
    end

    # Check if there's a valid invitation token for this community
    def valid_invitation_token?
      return false unless invitation_token.present?

      invitation = BetterTogether::CommunityInvitation.find_by(
        token: invitation_token,
        invitable: record
      )

      invitation.present? && invitation.status_pending?
    end

    # Check if the user is a member of this specific community
    def member_of_community?
      return false unless agent.present?

      BetterTogether::PersonCommunityMembership.exists?(
        member: agent,
        joinable: record,
        status: 'active'
      )
    end

    # Check if the user is the creator of this specific community
    def creator_of_community?
      creator_of?(record)
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        platform_scoped.order(updated_at: :desc).where(permitted_query)
      end

      protected

      # rubocop:todo Metrics/MethodLength
      def permitted_query # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        communities_table = ::BetterTogether::Community.arel_table
        person_community_memberships_table = ::BetterTogether::PersonCommunityMembership.arel_table

        query = visible_privacy_query(communities_table)

        if permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
          query = query.or(communities_table[:privacy].eq('private'))
        elsif agent
          query = query.or(
            communities_table[:id].in(
              person_community_memberships_table
                .where(person_community_memberships_table[:member_id]
                .eq(agent.id))
                .where(person_community_memberships_table[:status].eq('active'))
                .project(:joinable_id)
            )
          ).or(
            communities_table[:creator_id].eq(agent.id)
          )
        end

        # Add logic for invitation token access
        if invitation_token.present?
          invitation_table = ::BetterTogether::CommunityInvitation.arel_table
          community_ids_with_valid_invitations = invitation_table
                                                 .where(invitation_table[:token].eq(invitation_token))
                                                 .where(invitation_table[:status].eq('pending'))
                                                 .project(:invitable_id)

          query = query.or(communities_table[:id].in(community_ids_with_valid_invitations))
        end

        query
      end
      # rubocop:enable Metrics/MethodLength
    end

    private

    def can_manage_community?
      permitted_to?('manage_community_settings', record) ||
        permitted_to?('manage_community_members', record) ||
        platform_manager?
    end
  end
end
