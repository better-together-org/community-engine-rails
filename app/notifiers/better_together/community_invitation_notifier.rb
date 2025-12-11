# frozen_string_literal: true

module BetterTogether
  # Notifier for community invitation notifications
  # Inherits from InvitationNotifierBase for shared notification functionality
  class CommunityInvitationNotifier < InvitationNotifierBase
    deliver_by :email, mailer: 'BetterTogether::CommunityInvitationsMailer', method: :invite, params: :email_params,
                       queue: :mailers

    notification_methods do
      delegate :title, :body, :invitation, :invitable, to: :community
    end

    private

    def title_i18n_key
      'better_together.notifications.community_invitation.title'
    end

    def body_i18n_key
      'better_together.notifications.community_invitation.body'
    end

    def title_i18n_vars
      { community_name: invitable&.name }
    end

    def body_i18n_vars
      { community_name: invitable&.name }
    end

    def default_title
      'You have been invited to join a community'
    end

    def default_body
      'Invitation to join %<community_name>s'
    end
  end
end
