# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      # Brings an entitlement in line with its source, then its grants in line with the plan.
      #
      # The source decides the status (see State for a subscription; a paid order is active until it is
      # refunded). Becoming active makes the plan's grants; staying active or in grace keeps them, adding any
      # the plan gained and taking away any it lost; lapsing or being revoked takes away only what the
      # entitlement owns. Paying again reinstates a lapsed entitlement.
      #
      # **Safe to repeat**, and it never touches the payment: a handler that fails is reported, the others still
      # run, and the whole thing raises Incomplete at the end so the job that called it is retried.
      class Sync
        class Incomplete < StandardError; end

        def self.subscription(term) = new(source: term.pay_subscription, term:).call

        def self.order(order) = new(source: order).call

        def initialize(source:, term: nil)
          @source = source
          @term = term
        end

        def call
          state = current_state
          entitlement = find_or_start(state)
          return unless entitlement

          failures = Entitlement.transaction { entitlement.with_lock { converge(entitlement, state) } }
          # After the work is committed, so what did apply stays applied while the caller is told to try again.
          raise Incomplete, failures.map(&:message).join('; ') if failures.any?

          entitlement
        rescue ActiveRecord::RecordNotUnique
          # The same plan is already live for this beneficiary from another source: nothing more to give.
          Rails.logger.warn('[billing] entitlement already live for that beneficiary and plan')
          nil
        end

        private

        attr_reader :source, :term

        def subscription? = source.is_a?(Pay::Subscription)

        def current_state
          return State.call(source, term) if subscription?

          order_state
        end

        # A paid one-time order is active; refunded or cancelled, revoked. A part-refund changes nothing.
        def order_state
          case source.status
          when 'paid', 'partially_refunded' then State::Result.new(status: 'active', ends_at: nil, grace_ends_at: nil)
          when 'refunded', 'cancelled' then State::Result.new(status: 'revoked', ends_at: nil, grace_ends_at: nil)
          else State::Result.new(status: 'pending', ends_at: nil, grace_ends_at: nil)
          end
        end

        def plan = subscription? ? term.plan : Subscriptions::Start.single_plan(source)
        def platform = source.platform
        def beneficiary = subscription? ? term.beneficiary_or_payer : (source.on_behalf_of || source.buyer)

        def existing
          platform.billing_entitlements.find_by(subscription? ? { pay_subscription_id: source.id } : { order_id: source.id })
        end

        # An entitlement exists once there is something to give; before that (pending, or never paid) there is none.
        def find_or_start(state)
          found = existing
          return found if found
          return unless state.live? && plan&.plan_grants&.exists?

          @created = true
          platform.billing_entitlements.create!(source_attributes.merge(plan:, beneficiary:, starts_at: Time.current))
        end

        def source_attributes = subscription? ? { pay_subscription: source } : { order: source }

        # Returns the failures, if any; the status is changed and the notice sent whatever they were.
        def converge(entitlement, state)
          before = @created ? nil : entitlement.status
          entitlement.update!(status: stored_status(state), ends_at: state.ends_at, grace_ends_at: state.grace_ends_at)
          failures = state.live? ? Reconcile.call(entitlement) : ReleaseAll.call(entitlement)
          announce(entitlement, before)
          failures
        end

        def stored_status(state) = state.status == 'pending' ? 'lapsed' : state.status

        def announce(entitlement, before)
          return if before == entitlement.status

          kind = case entitlement.status
                 when 'active' then 'entitlement_granted' if before != 'grace'
                 when 'lapsed', 'revoked' then 'entitlement_lapsed'
                 end
          Notifications.deliver(kind, subject: entitlement, dedupe_key: "#{kind}:#{entitlement.id}:#{entitlement.updated_at.to_i}") if kind
        end
      end
    end
  end
end
