# frozen_string_literal: true

module BetterTogether
  # Notifies an authenticated requester that their membership request was declined.
  class MembershipRequestDeclinedNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications

    required_param :membership_request

    validates :record, presence: true

    def membership_request
      params[:membership_request] || record
    end

    def community
      membership_request.target if membership_request.target.is_a?(BetterTogether::Community)
    end

    def locale
      recipient&.locale || I18n.locale || I18n.default_locale
    end

    def title
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.membership_request_declined.title',
          community_name: community_name,
          default: 'Membership request declined for %<community_name>s'
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.membership_request_declined.body',
          community_name: community_name,
          default: 'Your request to join %<community_name>s was declined'
        )
      end
    end

    def build_message(_notification)
      { title:, body:, url: review_path }
    end

    notification_methods do
      delegate :membership_request, :title, :body, :review_path, to: :event
    end

    private

    def review_path
      return unless community&.persisted? && membership_request.persisted?

      BetterTogether::Engine.routes.url_helpers.community_membership_request_path(
        community,
        membership_request,
        locale:
      )
    end

    def review_url
      return unless community&.persisted? && membership_request.persisted?

      BetterTogether::Engine.routes.url_helpers.community_membership_request_url(
        community,
        membership_request,
        locale:
      )
    end

    def community_name
      community&.name || I18n.t('better_together.membership_requests.fields.target', default: 'Community')
    end
  end
end
