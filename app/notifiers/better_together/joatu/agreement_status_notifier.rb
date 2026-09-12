# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Notifies offer and request creators when an agreement status changes
    class AgreementStatusNotifier < ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                                queue: :notifications

      deliver_by :email, mailer: 'BetterTogether::JoatuMailer', method: :agreement_status_changed,
                         params: :email_params, queue: :mailers do |config|
        config.if = -> { recipient_has_email? }
      end

      validates :record, presence: true

      def agreement
        record
      end

      notification_methods do
        delegate :agreement, to: :event
      end

      def identifier
        agreement.id
      end

      def url
        ::BetterTogether::Engine.routes.url_helpers.joatu_agreement_url(agreement, locale: I18n.locale)
      end

      # rubocop:disable Style/FormatStringToken -- i18n %{key} interpolation, not Ruby format
      def title
        I18n.with_locale(locale) do
          I18n.t('better_together.notifications.joatu.agreement_status_changed.title',
                 status: agreement.status,
                 default: 'Agreement %{status}')
        end
      end

      def body
        I18n.with_locale(locale) do
          I18n.t('better_together.notifications.joatu.agreement_status_changed.body',
                 offer: agreement.offer.name,
                 request: agreement.request.name,
                 status: agreement.status,
                 default: 'The agreement between "%{offer}" and "%{request}" was %{status}.')
        end
      end
      # rubocop:enable Style/FormatStringToken

      def build_message(notification)
        I18n.with_locale(locale_for_notification(notification)) do
          {
            title:,
            body:,
            identifier:,
            url:,
            unread_count: notification.recipient.notifications.unread.count
          }
        end
      end

      def email_params(_notification)
        { agreement: }
      end
    end
  end
end
