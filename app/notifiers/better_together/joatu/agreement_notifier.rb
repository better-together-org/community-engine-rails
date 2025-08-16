# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Sends notifications when a new agreement is created
    class AgreementNotifier < ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message
      deliver_by :email,
                 mailer: 'BetterTogether::JoatuMailer',
                 method: :agreement_created,
                 params: :email_params do |config|
        config.if = -> { recipient.email.present? && recipient.notification_preferences['notify_by_email'] }
      end

      validates :record, presence: true

      notification_methods do
        delegate :agreement, :offer, :request, :title, :body, :url, to: :event
      end

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
        ::BetterTogether::Engine.routes.url_helpers.joatu_agreement_url(agreement, locale: I18n.locale)
      end

      def title
        I18n.t('better_together.notifications.joatu.agreement_created.title', default: 'Agreement created')
      end

      def body
        I18n.t('better_together.notifications.joatu.agreement_created.content',
               offer: offer.name,
               request: request.name,
               default: "Agreement between #{offer.name} and #{request.name} was created")
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
