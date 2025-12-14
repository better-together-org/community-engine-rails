# frozen_string_literal: true

module BetterTogether
  module Communities
    class InvitationsController < BetterTogether::Invitations::BaseController # rubocop:todo Style/Documentation
      private

      # Template method implementations

      def invitation_class
        BetterTogether::CommunityInvitation
      end

      def invitable_resource
        @community
      end

      def mailer_class
        BetterTogether::CommunityInvitationsMailer
      end

      def notifier_class
        BetterTogether::CommunityInvitationNotifier
      end

      def table_body_id
        'community_invitations_table_body'
      end

      def invitation_row_partial
        'better_together/shared/invitation_row'
      end

      def generate_resend_path(invitation)
        better_together.resend_community_invitation_path(@community, invitation)
      end

      def generate_destroy_path(invitation)
        better_together.community_invitation_path(@community, invitation)
      end

      def set_invitable_resource
        @community = BetterTogether::Community.friendly.find(params[:community_id])
      rescue StandardError
        render_not_found
      end

      # Communities exclude existing members
      def additional_exclusions(invited_ids)
        existing_member_ids = @community.person_community_memberships.pluck(:member_id)
        (invited_ids + existing_member_ids).uniq
      end
    end
  end
end
