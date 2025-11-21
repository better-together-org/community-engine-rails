# frozen_string_literal: true

module BetterTogether
  class CommunityInvitationsMailer < ApplicationMailer # rubocop:todo Style/Documentation
    # Parameterized mailer: Noticed calls mailer.with(params).invite
    # so read the invitation from params rather than using a positional arg.
    def invite
      invitation = params[:invitation]
      setup_invitation_data(invitation)

      to_email = invitation&.invitee_email.to_s
      return if to_email.blank?

      send_invitation_email(invitation, to_email)
    end

    private

    def setup_invitation_data(invitation)
      @invitation = invitation
      @community = invitation&.invitable
      @invitation_url = invitation&.url_for_review
    end

    def send_invitation_email(invitation, to_email)
      # Use the invitation's locale for proper internationalization
      I18n.with_locale(invitation&.locale) do
        mail(to: to_email,
             subject: I18n.t('better_together.community_invitations_mailer.invite.subject',
                             community_name: @community&.name,
                             default: 'You are invited to join %<community_name>s'))
      end
    end
  end
end
