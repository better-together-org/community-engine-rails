# frozen_string_literal: true

module BetterTogether
  module Billing
    # For a billing record that hangs off a parent (an order line, a payment, a refund): it
    # takes its platform from the parent, never from the request, and must agree with the
    # parent's platform and, where it has one, currency. The database enforces the platform with a composite
    # foreign key; this gives the clear error first.
    #
    # The including model defines `billing_parent` (its order or payment) and has PlatformBound.
    module ParentBound
      extend ActiveSupport::Concern

      included do
        validate :agrees_with_billing_parent
      end

      private

      def billing_parent = raise(NotImplementedError, "#{self.class}#billing_parent")

      # Overrides PlatformBound's: the parent decides before the request does.
      def assign_platform_from_current_context
        self.platform_id ||= billing_parent&.platform_id
        super
      end

      def agrees_with_billing_parent
        parent = billing_parent
        return unless parent

        errors.add(:platform, :platform_owner_mismatch) if differs?(platform_id, parent.platform_id)
        errors.add(:currency, :currency_mismatch) if has_attribute?(:currency) && differs?(currency, parent.currency)
      end

      def differs?(mine, theirs) = mine.present? && theirs.present? && mine != theirs
    end
  end
end
