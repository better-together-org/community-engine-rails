# frozen_string_literal: true

module BetterTogether
  # Notifies reviewers when a new membership request is ready for review.
  class MembershipRequestSubmittedNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications
    deliver_by :email, mailer: 'BetterTogether::MembershipRequestMailer', method: :submitted, params: :email_params,
                       queue: :mailers do |config|
      config.if = -> { recipient_has_email? }
    end

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
          'better_together.notifications.membership_request_submitted.title',
          community_name: community_name,
          default: 'New membership request for %<community_name>s'
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.membership_request_submitted.body',
          requestor_name:,
          community_name: community_name,
          default: '%<requestor_name>s asked to join %<community_name>s'
        )
      end
    end

    def build_message(_notification)
      { title:, body:, url: review_path }
    end

    def email_params(_notification)
      { membership_request:, recipient:, review_url: review_url }
    end

    notification_methods do
      delegate :membership_request, :title, :body, :review_path, :email_params, to: :event

      def recipient_has_email?
        recipient.respond_to?(:email) && recipient.email.present? &&
          (!recipient.respond_to?(:notification_preferences) ||
           recipient.notification_preferences.fetch('notify_by_email', true))
      end
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

    def requestor_name
      membership_request.requestor_name.presence || membership_request.creator&.name || membership_request.requestor_email
    end

    def community_name
      community&.name || I18n.t('better_together.membership_requests.fields.target', default: 'Community')
    end
  end
end
