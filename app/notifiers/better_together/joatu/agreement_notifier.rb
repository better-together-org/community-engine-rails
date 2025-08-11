# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Sends notifications when a new agreement is created
    class AgreementNotifier < ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message
      deliver_by :email, mailer: 'BetterTogether::JoatuMailer', method: :agreement_created, params: :email_params do |config|
        config.if = -> { recipient.email.present? && recipient.notification_preferences['notify_by_email'] }
      end

      validates :record, presence: true

      # Helper method to access the agreement
      def agreement
        record
      end

      def offer
        agreement.offer
      end

      def request
        agreement.request
      end

      def identifier
        agreement.id
      end

      def url
        ::BetterTogether::Engine.routes.url_helpers.root_url(locale: I18n.locale)
      end

      def title
        I18n.t('better_together.notifications.joatu.agreement_created.title')
      end

      def body
        I18n.t('better_together.notifications.joatu.agreement_created.content',
               offer: offer.name,
               request: request.name)
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
        { agreement: agreement }
      end
    end
  end
end
