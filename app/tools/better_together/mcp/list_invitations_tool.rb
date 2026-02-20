# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list invitations for the current user
    # Shows invitations the user can manage based on their permissions
    class ListInvitationsTool < ApplicationTool
      description 'List invitations the current user can manage, with optional status filter'

      arguments do
        optional(:status_filter)
          .filled(:string)
          .description('Filter by status: pending, accepted, or declined')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # List invitations with authorization
      # @param status_filter [String, nil] Optional status filter
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of invitation objects
      def call(status_filter: nil, limit: 20)
        return auth_required_response unless current_user

        with_timezone_scope do
          invitations = fetch_invitations(status_filter, limit)
          result = JSON.generate(invitations.map { |inv| serialize_invitation(inv) })

          log_invocation('list_invitations', { status_filter: status_filter, limit: limit }, result.bytesize)
          result
        end
      end

      private

      def auth_required_response
        JSON.generate({ error: 'Authentication required' })
      end

      def fetch_invitations(status_filter, limit)
        invitations = accessible_invitations
        invitations = invitations.where(status: status_filter) if status_filter.present?
        invitations.order(created_at: :desc).limit([limit, 100].min)
      end

      # InvitationPolicy::Scope raises NotImplementedError for non-platform-managers
      # so we handle scope resolution manually
      def accessible_invitations
        person = current_user.person
        scope = BetterTogether::Invitation.includes(:inviter, :invitee, :role)
        return scope.all if person&.permitted_to?('manage_platform')

        scope.where(inviter: person).or(scope.where(invitee: person))
      end

      def serialize_invitation(invitation)
        invitation_attributes(invitation).merge(invitation_metadata(invitation))
      end

      def invitation_attributes(invitation)
        {
          id: invitation.id,
          status: invitation.status,
          invitee_email: invitation.invitee_email,
          invitation_type: invitation.invitation_type.to_s,
          locale: invitation.locale
        }
      end

      def invitation_metadata(invitation)
        {
          inviter_name: invitation.inviter&.name,
          invitee_name: invitation.invitee&.name,
          role_name: invitation.role&.name,
          valid_from: invitation.valid_from&.iso8601,
          valid_until: invitation.valid_until&.iso8601,
          created_at: invitation.created_at&.iso8601
        }
      end
    end
  end
end
