# frozen_string_literal: true

module BetterTogether
  module Billing
    module Checkout
      # Where to send a buyer to pay an order through a processor: the processor's hosted checkout
      # (a session created now, or the one already made), or, when the payment needs the buyer to act
      # (a bank confirmation), the processor's own page for that.
      #
      # It never takes the buyer to a Pay page: Pay's own payment page is closed because it is not
      # signed in and calls the processor with a caller-supplied id. This is reached from the buyer's
      # order, after the order's owner was checked.
      #
      #   Checkout::Start.call(order:, success_url:, cancel_url:)  # => "https://..."
      #
      # An order paid in several parts can have more than one processor payment waiting; `payment:` says which.
      class Start
        class Unavailable < StandardError; end

        def self.call(...) = new(...).call

        def initialize(order:, success_url:, cancel_url:, payment: nil)
          @order = order
          @chosen = payment
          @success_url = success_url
          @cancel_url = cancel_url
        end

        def call
          raise Unavailable, 'there is nothing to pay' unless payment
          raise Unavailable, 'that processor is not available' unless adapter&.supports?(:checkout) && context

          action_url || start_session
        end

        private

        attr_reader :order, :success_url, :cancel_url

        # The payment the buyer still has to make: the one asked for, else the oldest one in flight through a processor.
        def payment
          @payment ||= begin
            remote = order.payments.in_flight.order(:created_at).select(&:remote?)
            @chosen ? remote.find { |candidate| candidate.id == @chosen.id } : remote.first
          end
        end

        def adapter = @adapter ||= Billing.processor_adapter(payment.processor)

        def context = @context ||= Configuration.context_for(order.platform, payment.processor)

        def action_url
          return unless payment.failure_code == 'action_required'

          https(adapter.payment_action_url(context:, order:))
        end

        def start_session
          session = adapter.create_checkout_session(**session_arguments)
          payment.update!(processor_session_reference: session.reference)
          flag_session_tax(session)
          https(session.url)
        end

        def session_arguments
          { context:, order:, payment:, success_url:, cancel_url:, idempotency_key: "checkout:#{payment.id}", metadata:, **tax_input }
        end

        # The tax core worked out for the order, so the processor shows and charges that amount instead of its own.
        # An adapter written before the tax inputs existed does not name them, so it is not handed keywords it would reject;
        # it charges its own amount and Payments::Succeed flags any difference.
        def tax_input
          return {} unless adapter_takes_tax?

          { tax_cents: order.added_tax_cents, included_tax_cents: order.included_tax_cents.to_i,
            prices_include_tax: order.prices_include_tax }
        end

        def adapter_takes_tax?
          params = adapter.method(:create_checkout_session).parameters
          params.any? { |kind, name| kind == :keyrest || (%i[key keyreq].include?(kind) && name == :tax_cents) }
        end

        # A processor that says how much tax it will charge, and says something other than what core worked out.
        def flag_session_tax(session)
          return if session.tax_cents.nil? || session.tax_cents == order.added_tax_cents

          Notifications.deliver('payment_amount_mismatch', subject: payment, dedupe_key: "session-tax-mismatch:#{payment.id}")
        end

        # What the processor carries back to us on the session, its payment intent and its subscription.
        def metadata
          { bt_order_id: order.id, bt_payment_id: payment.id, bt_platform_id: order.platform_id }
        end

        # Only an https address is ever redirected to: an adapter bug must not become an open redirect.
        def https(url)
          uri = URI.parse(url.to_s)
          raise Unavailable, 'the processor gave no usable address' unless uri.is_a?(URI::HTTPS) && uri.host.present?

          uri.to_s
        rescue URI::InvalidURIError
          raise Unavailable, 'the processor gave no usable address'
        end
      end
    end
  end
end
