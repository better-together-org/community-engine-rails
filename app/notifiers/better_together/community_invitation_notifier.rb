# frozen_string_literal: true

module BetterTogether
  class CommunityInvitationNotifier < ApplicationNotifier # rubocop:todo Style/Documentation
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications
    deliver_by :email, mailer: 'BetterTogether::CommunityInvitationsMailer', method: :invite, params: :email_params,
                       queue: :mailers

    required_param :invitation

    notification_methods do
      delegate :title, :body, :invitation, :invitable, to: :community
    end

    def invitation = params[:invitation]
    def invitable = params[:invitable] || invitation&.invitable

    def locale
      params[:invitation]&.locale || I18n.locale || I18n.default_locale
    end

    def title
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.community_invitation.title',
               community_name: invitable&.name, default: 'You have been invited to join a community')
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.community_invitation.body',
               community_name: invitable&.name, default: 'Invitation to join %<community_name>s')
      end
    end

    def build_message(_notification)
      # Pass the invitable (community) as the notification url object so views can
      # link to the community record (consistent with other notifiers that pass
      # domain objects like agreement/request).
      { title:, body:, url: invitation.url_for_review }
    end

    def email_params(_notification)
      # Include the invitation and the invitable (community) so mailers and views
      # have the full context without needing to resolve the invitation.
      { invitation: params[:invitation], invitable: }
    end
  end
end
