# frozen_string_literal: true

module BetterTogether
  class CommunityPolicy < PlatformRecordPolicy # rubocop:todo Style/Documentation
    include SelfServicePublishablePolicy

    def index?
      true # Allow all users to view community index (scope filters appropriately)
    end

    def show?
      public_or_member_scoped_community?(record) ||
        member_of_community? ||
        creator_of_community? ||
        manages_community? ||
        invitation? ||
        valid_invitation_token?
    end

    # Gate for the record's attached media (ActiveStorageSecurity#enforce_download_policy!): the same
    # audience as the record itself. Without this method the gate lets any signed-in user through.
    def download?
      show?
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
      user.present? && (manages_community? || permitted_to?('update_community', record) || platform_operates_public?)
    end

    def manage_integrations?
      update?
    end

    def create_events?
      return false unless user.present? && agent.present?

      # Platform managers host events for public communities; private ones need the organizer's grant
      return true if platform_operates_public?

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
        manages_community?
    end

    def manage_roles?
      return false unless user.present?

      permitted_to?('manage_community_roles', record) || manages_community? || platform_operates_public?
    end

    # Platform managers moderate any community regardless of privacy; none of these opens the
    # community's content or member list.
    def suspend? = platform_moderates?
    def quarantine? = platform_moderates?
    def hide? = platform_moderates?

    # No separate quota-usage permission exists yet; anyone who manages this community's
    # settings or members sees its usage, and platform managers see the aggregate.
    def view_quota_usage?
      return false unless user.present?

      manages_community? || platform_manager?
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && !record.protected? && !record.host? &&
        (platform_manager? || permitted_to?('delete_community', record))
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

      BetterTogether::PersonCommunityMembership.current.exists?(member: agent, joinable: record)
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

      # rubocop:todo-next Metrics/MethodLength
      def permitted_query # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        communities_table = ::BetterTogether::Community.arel_table
        person_community_memberships_table = ::BetterTogether::PersonCommunityMembership.arel_table

        query = visible_privacy_query(communities_table)

        if agent
          query = query.or(
            communities_table[:id].in(
              person_community_memberships_table
                .where(person_community_memberships_table[:member_id]
                .eq(agent.id))
                .where(BetterTogether::PersonCommunityMembership.current_condition)
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
    end

    private

    # The actor's own community role grants settings or member management here.
    def manages_community?
      permitted_to?('manage_community_settings', record) ||
        permitted_to?('manage_community_members', record)
    end

    # Platform managers operate public communities only; private ones need the organizer's grant.
    def platform_operates_public?
      platform_manager? && privacy_public?(record)
    end

    def platform_moderates?
      user.present? && platform_manager?
    end
  end
end
