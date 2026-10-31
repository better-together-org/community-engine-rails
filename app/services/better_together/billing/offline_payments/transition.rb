# frozen_string_literal: true

module BetterTogether
  module Billing
    module OfflinePayments
      # Every move an offline payment makes. The rules, in order of importance:
      #
      # 1. THE SELLER'S WORD IS ENOUGH. `receive` (the seller saying the money arrived) works from
      #    awaiting, claimed or expired, whether or not the buyer ever claimed anything. Nothing
      #    here reads the buyer's claim as a condition. A buyer who paid in person, or sent a
      #    transfer without telling anyone, is paid like any other.
      # 2. THE BUYER'S CLAIM IS ONLY A FLAG. `claim` records "I sent it" (with an optional
      #    reference) and tells the seller. It never changes what the seller may do. After the
      #    seller has confirmed, or the payment is closed, a claim is ignored without error.
      # 3. A LATE PAYMENT IS NOT LOST. An expired payment can still be confirmed; the place it held
      #    is taken again first, and if it is gone the seller is told and nothing is recorded as paid.
      # 4. NOBODY CONFIRMS THEIR OWN PURCHASE unless they are a steward of the platform.
      #
      # Each move runs under the offline payment's lock, so a double click or two people acting
      # together moves it once, writes one event, and notifies once.
      class Transition # rubocop:disable Metrics/ClassLength
        class Refused < StandardError; end
        class NotAllowed < Refused; end
        class SelfConfirmation < Refused; end
        class PlaceGone < Refused; end
        class TooManyClaims < Refused; end

        # How many times a buyer can send a claim (to add a reference) for one payment.
        CLAIM_LIMIT = 5

        class << self
          def claim(offline, reference: nil) = new(offline).claim(reference:)

          def receive(offline, by:, reference: nil, received_on: nil) = new(offline, actor: by).receive(reference:, received_on:)

          def clear(offline, by:) = new(offline, actor: by).clear

          def bounce(offline, by:) = new(offline, actor: by).bounce

          def reject(offline, by:, reason: nil) = new(offline, actor: by).reject(reason:)

          # The order lapsed (`expired`) or was cancelled: the waiting payment is closed with it.
          def release(offline, outcome) = new(offline).release(outcome)
        end

        def initialize(offline, actor: nil)
          @offline = offline
          @actor = actor
        end

        # The buyer says they sent it.
        def claim(reference:)
          offline.with_lock do
            next offline unless offline.waiting? || offline.expired?
            raise TooManyClaims, 'that has been sent too many times' if offline.claim_count >= CLAIM_LIMIT

            record_claim(reference)
          end
          offline
        end

        # The seller says the money arrived. A cheque becomes `received`; cash and an e-transfer `confirmed`.
        def receive(reference:, received_on:)
          take_the_money(reference:, received_on:)
        rescue PlaceGone
          Notifications.deliver('payment_place_gone', subject: offline, dedupe_key: "place-gone:#{offline.id}", actor:)
          raise
        end

        # A received cheque cleared.
        def clear
          offline.with_lock do
            next offline if offline.cleared?

            ensure_allowed!('cleared')
            offline.update!(status: 'cleared', cleared_at: Time.current)
            succeed_payment if offline.grant_on == 'cleared'
            announce('cheque_cleared')
          end
          offline
        end

        # A received cheque bounced: what it granted is reversed, or never granted.
        def bounce
          offline.with_lock do
            next offline if offline.bounced?

            ensure_allowed!('bounced')
            offline.update!(status: 'bounced', bounced_at: Time.current)
            reverse_payment
            announce('cheque_bounced')
          end
          offline
        end

        # The seller says they will not take this payment (nothing arrived, or it cannot be honoured).
        def reject(reason:)
          offline.with_lock do
            next offline if offline.rejected?

            ensure_allowed!('rejected')
            offline.update!(status: 'rejected', rejected_at: Time.current, rejection_reason: reason)
            drop_payment
            announce('payment_rejected')
          end
          offline
        end

        def release(outcome)
          offline.with_lock do
            next offline unless offline.waiting?

            status = outcome.to_s == 'expired' ? 'expired' : 'cancelled'
            offline.update!(status:, "#{status}_at": Time.current)
            Audit.record(offline, event_type: 'payment_expired', outcome_kind: 'payment_expired') if status == 'expired'
          end
          offline
        end

        private

        attr_reader :offline, :actor

        def order = offline.order

        def take_the_money(reference:, received_on:)
          offline.with_lock do
            next offline if offline.money_received?

            ensure_allowed!(offline.receipt_status)
            refuse_own_purchase!
            take_the_place_again if offline.expired?
            record_receipt(reference, received_on)
          end
          offline
        end

        def record_receipt(reference, received_on)
          offline.update!(receipt_attributes(reference, received_on))
          succeed_payment if offline.grants_on_receipt?
          announce(offline.cheque? ? 'cheque_received' : 'payment_confirmed')
        end

        # The first time the buyer says it, the seller is told; later notes only update what they wrote.
        def record_claim(reference)
          first = offline.claim_count.zero?
          offline.update!(claim_attributes(reference))
          announce('payment_claimed', notify: first)
        end

        def claim_attributes(reference)
          attributes = { claim_count: offline.claim_count + 1, claimed_at: offline.claimed_at || Time.current,
                         buyer_reference: reference.presence || offline.buyer_reference }
          offline.waiting? ? attributes.merge(status: 'claimed') : attributes
        end

        def receipt_attributes(reference, received_on)
          stamp = offline.cheque? ? :received_at : :confirmed_at
          { status: offline.receipt_status, confirmed_by: actor, stamp => Time.current, seller_reference: reference, received_on: }
        end

        def ensure_allowed!(status)
          raise NotAllowed, "a payment that is #{offline.status} cannot become #{status}" unless offline.can_become?(status)
          raise NotAllowed, 'only a cheque can clear or bounce' if %w[cleared bounced].include?(status) && !offline.cheque?
        end

        def refuse_own_purchase!
          return unless actor && own_purchase?
          return if actor.permitted_to?(:manage_platform, offline.platform)

          raise SelfConfirmation, 'you cannot confirm a payment for your own purchase'
        end

        def own_purchase?
          beneficiary = order.on_behalf_of
          [order.buyer_id, (beneficiary.id if beneficiary.is_a?(BetterTogether::Person))].include?(actor.id)
        end

        # An expired payment is paid late: its hold was let go, so take the place again and open
        # a fresh payment for it. If the place is gone, nothing changes.
        def take_the_place_again
          order.lines.each { |line| line.purchasable.reserve!(quantity: line.quantity) }
          offline.update!(payment: late_payment)
        rescue StandardError => e
          raise PlaceGone, e.message
        end

        def late_payment
          Payments::Create.call(order:, processor: offline.processor, amount_cents: order.balance_cents,
                                idempotency_key: "offline:#{order.id}:#{offline.id}:late")
        end

        def succeed_payment
          raise NotAllowed, 'the payment is no longer waiting' unless offline.payment.reload.pending?

          Payments::Succeed.call(offline.payment, reference: offline.seller_reference)
        end

        # The money is not coming (or is going back). Nothing was granted: the payment fails and
        # the order is cancelled so what it held is released. Something was granted: it is refunded.
        def reverse_payment
          payment = offline.payment.reload
          return drop_payment unless payment.succeeded?

          Refunds::Record.call(payment:, amount_cents: payment.refundable_cents, idempotency_key: "bounce:#{offline.id}", reason: 'bounced',
                               recorded_by: actor, notify: false)
        end

        def drop_payment
          Payments::Fail.call(offline.payment)
          Orders::Cancel.call(order)
        rescue Orders::Cancel::Refused
          nil # some other payment has money against the order; it stays open
        end

        # Logs the event and, when asked, tells the other side. The person acting is never told.
        def announce(kind, notify: true)
          Audit.record(offline, event_type: kind, outcome_kind: kind, actor:)
          Notifications.deliver(kind, subject: offline, actor:) if notify
        end
      end
    end
  end
end
