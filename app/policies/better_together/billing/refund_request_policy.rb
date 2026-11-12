# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::RefundRequest. A buyer asks for money back on their own order and may withdraw a request
    # that is still waiting; a steward sees and decides the requests for what the platform itself sells.
    class RefundRequestPolicy < OwnerPolicy
      # The order a request would be for (a new request has the order; a saved one has it too).
      def new? = create?

      def create?
        order = record.order
        user.present? && order.present? && buyer?(order) && order.platform_id == Current.platform&.id &&
          RefundRequest.refundable_cents_for(order).positive? && order.refund_requests.pending.none?
      end

      # The buyer withdraws their own request while it is waiting.
      def cancel? = user.present? && record.pending? && buyer?(record.order)

      # The steward's queue and decisions.
      def index? = manage_billing?
      def show? = manage_billing? && record.order.sold_by_platform?
      def decide? = show? && record.pending?

      # The requests for what the platform itself sells, for those who manage its billing.
      class Scope < OwnerPolicy::Scope
        def resolve
          platform = Current.platform
          return scope.none unless user && platform && BetterTogether::Billing.enabled?(platform) && user.permitted_to?(:manage_platform,
                                                                                                                        platform)

          scope.for_platform(platform).joins(:order).merge(BetterTogether::Billing::Order.sold_by_platform)
        end
      end

      private

      def buyer?(order)
        person = user.respond_to?(:person) ? user.person : nil
        person.present? && order.buyer_id == person.id
      end
    end
  end
end
