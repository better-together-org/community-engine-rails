# frozen_string_literal: true

module BetterTogether
  module C3
    # Notifies participants about C3 Tree Seeds lifecycle events:
    #   c3_locked        — payer's Tree Seeds reserved when an agreement is accepted
    #   c3_settled       — Tree Seeds transferred when an agreement is fulfilled
    #   c3_lock_released — reserved Tree Seeds returned when a settlement is cancelled
    #
    # Plain-language messages use Tree Seeds (not millitokens) to avoid technical jargon.
    # DID values, UUIDs, and internal identifiers are never included in message bodies.
    class SettlementNotifier < ApplicationNotifier
      include BetterTogether::C3Helper

      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                                queue: :notifications
      deliver_by :email,
                 mailer: 'BetterTogether::C3::SettlementMailer',
                 method: :settlement_notification,
                 params: :email_params, queue: :mailers do |config|
        config.if = -> { recipient_has_email? }
      end

      required_param :settlement
      required_param :event_type # :c3_locked | :c3_settled | :c3_lock_released

      validates :settlement, :event_type, presence: true

      def settlement
        params[:settlement]
      end

      def event_type
        params[:event_type]&.to_sym
      end

      def title
        case event_type
        when :c3_locked
          I18n.t('better_together.notifications.c3.settlement.locked.title',
                 default: 'Tree Seeds reserved')
        when :c3_settled
          I18n.t('better_together.notifications.c3.settlement.settled.title',
                 default: 'Tree Seeds exchanged')
        when :c3_lock_released
          I18n.t('better_together.notifications.c3.settlement.released.title',
                 default: 'Tree Seeds reservation released')
        end
      end

      # rubocop:disable Style/FormatStringToken -- i18n %{key} interpolation, not Ruby format
      def body # rubocop:todo Metrics/MethodLength
        amount = helpers.tree_seeds_display(settlement.c3_millitokens, include_emoji: false)
        case event_type
        when :c3_locked
          I18n.t('better_together.notifications.c3.settlement.locked.body',
                 amount: amount,
                 default: '%{amount} have been reserved for your agreement. ' \
                          'They will be released if the agreement is cancelled.')
        when :c3_settled
          I18n.t('better_together.notifications.c3.settlement.settled.body',
                 amount: amount,
                 default: '%{amount} have been exchanged. Your balance has been updated.')
        when :c3_lock_released
          I18n.t('better_together.notifications.c3.settlement.released.body',
                 amount: amount,
                 default: '%{amount} have been returned to your balance.')
        end
      end
      # rubocop:enable Style/FormatStringToken

      def identifier
        settlement.id
      end

      def url
        agreement = settlement.agreement
        ::BetterTogether::Engine.routes.url_helpers.joatu_agreement_url(agreement, locale: I18n.locale)
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

      def email_params(notification)
        { settlement: settlement, event_type: event_type, recipient: notification.recipient }
      end

      notification_methods do
        delegate :settlement, :event_type, :title, :body, :identifier, :url, to: :event

        def recipient_has_email?
          recipient.respond_to?(:email) && recipient.email.present? &&
            (!recipient.respond_to?(:notification_preferences) ||
             recipient.notification_preferences.fetch('notify_by_email', true))
        end
      end

      private

      def helpers
        @helpers ||= Object.new.extend(BetterTogether::C3Helper)
      end
    end
  end
end
