# frozen_string_literal: true

module BetterTogether
  module Billing
    module RefundRequests
      # A buyer asks for money back on an order. The request is checked against what can still be given back here
      # (see RefundRequest), then the people who manage the platform's billing and the buyer are told.
      class Create
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(order:, requester:, reason:, amount_cents: nil, details: nil)
          @order = order
          @requester = requester
          @attributes = { reason: reason.to_s, amount_cents: amount_cents.presence, details: details.to_s.strip.presence }
        end

        def call
          request = build.tap(&:save!)
          Notifications.deliver('refund_requested', subject: request, actor: requester)
          request
        rescue ActiveRecord::RecordInvalid => e
          raise Refused, e.record.errors.full_messages.to_sentence
        rescue ActiveRecord::RecordNotUnique
          raise Refused, I18n.t('better_together.billing.refund_requests.already_pending')
        end

        private

        attr_reader :order, :requester, :attributes

        def build = order.refund_requests.new(platform_id: order.platform_id, requester:, currency: order.currency, **attributes)
      end
    end
  end
end
