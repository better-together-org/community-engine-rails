# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::TaxRegistration: who collects tax, and on what terms.
    #
    # Like the payment method settings, it needs billing to be configurable, not already enabled,
    # so a platform can say how it collects tax before its first method is on.
    class TaxRegistrationPolicy < OwnerPolicy
      def index?  = manage_billing?
      def new?    = manage_billing?
      def create? = manage_billing?
      def edit?   = manage_billing?
      def update? = manage_billing?
      def show?   = false
      def destroy? = false

      # Registrations are visible once billing is configurable, not only once a method is on.
      class Scope < OwnerPolicy::Scope
        private

        def available?(platform) = BetterTogether::Billing.configurable?(platform)
      end

      private

      def billing_available?(owner) = BetterTogether::Billing.configurable?(owner)
    end
  end
end
