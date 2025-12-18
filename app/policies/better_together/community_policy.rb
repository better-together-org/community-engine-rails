# frozen_string_literal: true

module BetterTogether
  class CommunityPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      true # Allow all users to view community index (scope filters appropriately)
    end

    def show?
      record.privacy_public? ||
        member_of_community? ||
        creator_of_community? ||
        permitted_to?('manage_platform') ||
        invitation? ||
        valid_invitation_token?
    end

    def create?
      user.present? && (permitted_to?('manage_platform') || permitted_to?('create_community'))
    end

    def new?
      create?
    end

    def update?
      user.present? && (permitted_to?('manage_platform') || permitted_to?('update_community', record))
    end

    def create_events?
      update? &&
        BetterTogether::EventPolicy.new(user, BetterTogether::Event.new).create?
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && !record.protected? && !record.host? && (permitted_to?('manage_platform') || permitted_to?(
        'destroy_community', record
      ))
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
        joinable: record
      )
    end

    # Check if the user is the creator of this specific community
    def creator_of_community?
      return false unless agent.present?

      record.creator_id == agent.id
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.order(updated_at: :desc).where(permitted_query)
      end

      protected

      # rubocop:todo Metrics/MethodLength
      def permitted_query # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        communities_table = ::BetterTogether::Community.arel_table
        person_community_memberships_table = ::BetterTogether::PersonCommunityMembership.arel_table

        # Only list communities that are public and where the current person is a member or a creator
        query = communities_table[:privacy].eq('public')

        if permitted_to?('manage_platform')
          query = query.or(communities_table[:privacy].eq('private'))
        elsif agent
          query = query.or(
            communities_table[:id].in(
              person_community_memberships_table
                .where(person_community_memberships_table[:member_id]
                .eq(agent.id))
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
  end
end
