# frozen_string_literal: true

module BetterTogether
  module Billing
    # One notification about billing: an order placed or paid, a payment that failed, a refund, a
    # changed payment method, a pipeline that needs a person. What it says comes from the `kind`
    # (see Notifications::Catalog) and the `audience` it is for, in the reader's own language.
    #
    # It carries names, amounts, dates and a link to the order. It never carries payment
    # instructions, a payee's email, phone or address, what a buyer typed as a reference, a
    # processor's own text or an event payload: those could be used to redirect a payment, and an
    # email can be forwarded.
    #
    # The notification's `record` is a billing record, so it is stamped with that record's own
    # platform, not whichever one the request or job happens to be running as. Deliveries run on
    # the `billing` queue so a payment message never waits behind other jobs.
    class Notifier < ::ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message, queue: :billing
      deliver_by :email, mailer: 'BetterTogether::BillingMailer', method: :notification, params: :email_params, queue: :billing do |config|
        config.if = -> { send_email? }
      end

      required_param :kind, :audience

      validates :record, presence: true

      def kind = params[:kind].to_s

      def audience = params[:audience].to_sym

      def critical? = Notifications::Catalog.critical?(kind)

      def title = message_for(:title)

      def body = message_for(:body)

      def url = Notifications::Links.path(self, record)

      def build_message(notification)
        I18n.with_locale(locale_for_notification(notification)) { { title:, body:, url: } }
      end

      def email_params(notification)
        { recipient: notification.recipient, notifier: self }
      end

      notification_methods do
        delegate :kind, :audience, :critical?, :title, :body, :url, to: :event

        # A critical notice is emailed even to someone who turned emails off; the rest follow the choice.
        def send_email?
          recipient.respond_to?(:email) && recipient.email.present? && (event.critical? || recipient_has_email?)
        end
      end

      private

      # The record's own platform, never the ambient one.
      def resolved_platform_id
        (record.platform_id if record.respond_to?(:platform_id)) || super
      end

      def message_for(part)
        I18n.with_locale(locale) do
          I18n.t("better_together.billing.notifications.#{kind}.#{audience}.#{part}",
                 default: [:"better_together.billing.notifications.#{kind}.#{part}"], **interpolations)
        end
      end

      def interpolations
        order = Notifications::Links.order_of(record)
        { number: order&.number.to_s, amount: money(order&.total_cents, order&.currency), platform: record.try(:platform)&.name.to_s,
          method: method_label }
      end

      def method_label
        name = record.try(:processor)
        name ? I18n.t("better_together.billing.plans.payment_method_names.#{name}", default: name.to_s.humanize) : ''
      end

      def money(cents, currency)
        return '' unless cents && currency

        ActionController::Base.helpers.number_to_currency(Currency.to_major(cents, currency), unit: Currency.unit(currency),
                                                                                              precision: Currency.exponent(currency))
      end
    end
  end
end
