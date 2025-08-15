# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Notifies offer and request creators when an agreement status changes
    class AgreementStatusNotifier < ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message

      deliver_by :email, mailer: 'BetterTogether::JoatuMailer', method: :agreement_status_changed,
                         params: :email_params do |config|
        config.if = -> { send_email_notification? }
      end

      validates :record, presence: true

      def agreement
        record
      end

      notification_methods do
        delegate :agreement, to: :event

        def send_email_notification?
          recipient.respond_to?(:email) && recipient.email.present? &&
            recipient.respond_to?(:notification_preferences) &&
            recipient.notification_preferences['notify_by_email']
        end
      end

      def identifier
        agreement.id
      end

      def url
        ::BetterTogether::Engine.routes.url_helpers.joatu_agreement_url(agreement, locale: I18n.locale)
      end

      def title
        "Agreement #{agreement.status}"
      end

      def body
        "Agreement between #{agreement.offer.name} and #{agreement.request.name} was #{agreement.status}"
      end

      def build_message(notification)
        {
          title:,
          body:,
          identifier:,
          url:,
          unread_count: notification.recipient.notifications.unread.count
        }
      end

      def email_params(_notification)
        { agreement: }
      end
    end
  end
end
