# frozen_string_literal: true

module BetterTogether
  # Mailer for sending community invitation emails
  # Inherits from InvitationMailerBase for shared invitation email functionality
  class CommunityInvitationsMailer < InvitationMailerBase
    private

    def invitation_subject
      I18n.t('better_together.community_invitations_mailer.invite.subject',
             community_name: @invitable&.name,
             default: 'You are invited to join %<community_name>s')
    end

    def invitable_instance_variable
      :@community
    end
  end
end
