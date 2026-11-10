# frozen_string_literal: true

module BetterTogether
  module Billing
    # One notification about billing: an order placed or paid, a payment that failed, a refund, a
    # changed payment method, a pipeline that needs a person. What it says comes from the `kind`
    # (see Notifications::Catalog) and the `audience` it is for, in the reader's own language.
    #
    # It carries names, amounts, dates and a link to the order. A message about an order also carries the
    # full order summary (see `order_summary`), the same one the order pages show. It never carries payment
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

      # What the order says about money, for the email; nil when the notice is not about an order.
      def order_summary
        order = Notifications::Links.order_of(record)
        Orders::Summary.for_order(order) if order
      end

      def build_message(notification)
        I18n.with_locale(locale_for_notification(notification)) { { title:, body:, url: } }
      end

      def email_params(notification)
        { recipient: notification.recipient, notifier: self, address: address_for(notification.recipient) }
      end

      # Where an email to this person goes. The buyer of an order is written to at the address given when it was
      # placed (a walk-up sale records one, new or existing buyer alike); otherwise at the address on their account.
      def address_for(recipient)
        order = Notifications::Links.order_of(record)
        given = order.buyer_email if audience == :buyer && order && order.buyer_id == recipient.id
        given.presence || (recipient.email if recipient.respond_to?(:email))
      end

      notification_methods do
        delegate :kind, :audience, :critical?, :title, :body, :url, to: :event

        # A critical notice is emailed even to someone who turned emails off; the rest follow the choice.
        def send_email?
          event.address_for(recipient).present? && (event.critical? || recipient_has_email?)
        end
      end

      private

      # The record's own platform, never the ambient one.
      def resolved_platform_id
        (record.platform_id if record.respond_to?(:platform_id)) || super
      end

      def message_for(part)
        part = :body_expiring if part == :body && expiring_credit?
        I18n.with_locale(locale) do
          I18n.t("better_together.billing.notifications.#{kind}.#{audience}.#{part}",
                 default: [:"better_together.billing.notifications.#{kind}.#{part}"], **interpolations)
        end
      end

      def interpolations
        order = Notifications::Links.order_of(record)
        { number: order&.number.to_s, amount: amount_text(order), platform: record.try(:platform)&.name.to_s,
          method: method_label, expires: expiry_text, plan: plan_name, date: date_text }.merge(part_interpolations(order))
      end

      # For a part payment: what this payment brought in and what is left to pay on the order.
      def part_interpolations(order)
        return {} unless order

        { received: record.is_a?(Payment) ? money(record.amount_cents, order.currency) : '', left: money(order.balance_cents, order.currency) }
      end

      def plan_name = (subscription_term&.plan || record.try(:plan))&.name.to_s

      # The subscription a renewal notice is about.
      def subscription_term
        case record
        when SubscriptionTerm then record
        when SubscriptionPeriod then record.term
        end
      end

      # The date that matters for the kind: the end of the grace, of the subscription, or of the current period.
      def date_text
        return entitlement_date_text if record.is_a?(Entitlement)

        term = subscription_term
        return '' unless term

        date = case kind
               when 'renewal_overdue', 'grace_ending' then term.grace_ends_at
               when 'subscription_canceled' then term.pay_subscription.ends_at
               else term.pay_subscription.current_period_end
               end
        date ? I18n.l(date.to_date, format: :long, locale:) : ''
      end

      # When the access an entitlement gives runs out (or ran out), if it does.
      def entitlement_date_text
        date = record.grace_ends_at || record.ends_at
        date ? I18n.l(date.to_date, format: :long, locale:) : ''
      end

      # An order's total, or the amount of credit a lot adds.
      def amount_text(order)
        return money(record.amount_cents, record.account.currency) if record.is_a?(CreditLot)

        order ? order_amount_text(order) : term_amount_text
      end

      # The total, and how much of it is tax when the order carries any.
      def order_amount_text(order)
        total = money(order.total_cents, order.currency)
        return total unless order.tax_cents.positive?

        I18n.t('better_together.billing.notifications.amount_with_tax', amount: total, tax: money(order.tax_cents, order.currency), locale:)
      end

      # What a subscription costs each period, for a notice that has no invoice yet.
      def term_amount_text
        term = subscription_term
        term ? money(term.unit_amount_cents, term.currency) : ''
      end

      # Credit that lapses says when; credit that does not says nothing about it.
      def expiring_credit? = record.is_a?(CreditLot) && record.expires_at.present?

      def expiry_text = expiring_credit? ? I18n.l(record.expires_at.to_date, format: :long, locale:) : ''

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
