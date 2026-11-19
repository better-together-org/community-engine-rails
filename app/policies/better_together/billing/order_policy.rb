# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::Order.
    #
    # A buyer sees their own orders. A steward sees the orders of what the platform itself
    # sells (its "sales"), through the same #manage_billing? question as plans. Orders sold by a
    # community or person belong to that seller and are not visible through the platform's
    # screens.
    class OrderPolicy < OwnerPolicy
      def index? = user.present?
      def show? = bought_by_user?
      # Any signed-in person may start a checkout; what they may buy is decided by the plan and the agreements.
      def checkout? = user.present?
      def new? = false
      def create? = false
      def update? = false
      def destroy? = false

      # The buyer tells the seller they sent a payment made outside the platform.
      def claim? = bought_by_user?

      # The buyer adds a payment, or the rest, to their own order while something is left to pay.
      def add_payment? = bought_by_user? && record.try(:balance_cents).to_i.positive? && (record.open? || record.expired?)

      # The buyer pays their own order through a processor, and returns from it.
      def pay? = bought_by_user?
      def checkout_return? = bought_by_user?

      # A steward looking at what the platform sells.
      def sales? = manage_billing?
      def sale? = manage_billing? && record.try(:sold_by_platform?) == true
      # The seller records money given back.
      def refund? = sale?
      # The seller returns what was paid toward a sale, and cancels one that will not be completed.
      def return_payments? = sale?
      def cancel? = sale?
      # A sale made in person.
      def walk_up? = manage_billing?

      # The buyer's own orders on the current platform.
      class Scope < ApplicationPolicy::Scope
        def resolve
          platform = Current.platform
          person = user.respond_to?(:person) ? user.person : nil
          return scope.none unless platform && person

          scope.for_platform(platform).bought_by(person)
        end
      end

      private

      def bought_by_user?
        person = user.respond_to?(:person) ? user.person : nil
        person.present? && record.respond_to?(:buyer_id) && record.buyer_id == person.id
      end
    end
  end
end
