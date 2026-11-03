# frozen_string_literal: true

module BetterTogether
  module Billing
    module Refunds
      # A refund the processor accepted but had not finished (`pending`) is now known to have worked
      # (`succeeded`) or not (`failed`). A failed refund un-refunds: it stops counting, the payment goes
      # back to `succeeded` or `partially_refunded`, and the order back to `paid` or `partially_refunded`,
      # so the money we thought was returned is owed to the buyer again and the operators are told.
      # Safe to repeat: a refund that is already resolved is returned as it is.
      class Resolve
        RESULTS = %w[succeeded failed].freeze

        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(refund, status:)
          raise Refused, "a refund resolves to #{RESULTS.join(' or ')}" unless RESULTS.include?(status.to_s)

          @refund = refund
          @status = status.to_s
        end

        def call
          refund.payment.with_lock { resolve }
          refund
        end

        private

        attr_reader :refund, :status

        def resolve
          refund.reload
          return unless refund.status == 'pending'

          refund.update!(status:)
          payment = refund.payment.reload
          payment.refresh_refund_status!
          LocalSettlement.sync_refunds!(payment)
          Orders::Settle.call(payment.order)
          tell_operators if status == 'failed'
        end

        def tell_operators
          Notifications.deliver('refund_failed', subject: refund, dedupe_key: "refund-failed:#{refund.id}")
        end
      end
    end
  end
end
