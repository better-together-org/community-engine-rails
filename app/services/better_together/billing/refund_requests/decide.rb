# frozen_string_literal: true

module BetterTogether
  module Billing
    module RefundRequests
      # The seller decides a refund request, once: give back all that was asked, give back part, or decline. Giving money
      # back is recorded as ordinary refunds (Refunds::Record) against the order's payments Community Engine settles
      # itself, newest first, so tax, store credit and the order's status behave as for any refund. The buyer is told.
      #
      # Deciding twice is refused. Repeating the same click is safe: each refund has a key made from the request.
      class Decide
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(request:, decider:, outcome:, approved_amount_cents: nil, note: nil)
          @request = request
          @decider = decider
          @outcome = outcome.to_s
          @approved = approved_amount_cents
          @note = note.to_s.strip.presence
        end

        def call
          request.with_lock do
            raise Refused, I18n.t('better_together.billing.refund_requests.already_decided') unless request.pending?

            outcome == 'decline' ? decline : approve
          end
          Notifications.deliver('refund_request_decided', subject: request, actor: decider)
          request
        rescue Refunds::Record::Refused, ActiveRecord::RecordInvalid => e
          raise Refused, e.message
        end

        private

        attr_reader :request, :decider, :outcome, :approved, :note

        def decline
          raise Refused, I18n.t('better_together.billing.refund_requests.decline_needs_note') if note.blank?

          request.update!(status: 'declined', decision_note: note, decided_by: decider, decided_at: Time.current)
        end

        def approve
          available = RefundRequest.refundable_cents_for(request.order)
          wanted = request.amount_cents || available
          give = amount_to_give(wanted, available)
          hand_back(give)
          request.update!(status: give >= wanted ? 'approved' : 'partially_approved', approved_amount_cents: give,
                          decision_note: note, decided_by: decider, decided_at: Time.current)
        end

        def amount_to_give(wanted, available)
          give = approved.presence ? approved.to_i : [wanted, available].min
          raise Refused, I18n.t('better_together.billing.refund_requests.amount_invalid') unless give.positive? && give <= available

          give
        end

        def hand_back(cents)
          left = cents
          payments.each do |payment|
            break if left <= 0

            part = [left, payment.refundable_cents].min
            next unless part.positive?

            Refunds::Record.call(payment:, amount_cents: part, idempotency_key: "refund_request:#{request.id}:#{payment.id}",
                                 reason: 'requested_by_buyer', recorded_by: decider)
            left -= part
          end
        end

        def payments
          request.order.payments.select { |payment| Billing.local_method?(payment.processor) && payment.refundable_cents.positive? }
                                .sort_by(&:created_at).reverse
        end
      end
    end
  end
end
