# frozen_string_literal: true

module BetterTogether
  module Events
    class InvitationsController < BetterTogether::Invitations::BaseController # rubocop:todo Style/Documentation
      private

      # Template method implementations

      def invitation_class
        BetterTogether::EventInvitation
      end

      def invitable_resource
        @event
      end

      def mailer_class
        BetterTogether::EventInvitationsMailer
      end

      def notifier_class
        BetterTogether::EventInvitationNotifier
      end

      def table_body_id
        'event_invitations_table_body'
      end

      def invitation_row_partial
        'better_together/events/invitation_row'
      end

      def set_invitable_resource
        @event = BetterTogether::Event.friendly.find(params[:event_id])
      rescue StandardError
        render_not_found
      end

      # Events don't exclude existing members (use default implementation)
      # def additional_exclusions(invited_ids)
      #   invited_ids
      # end
    end
  end
end
