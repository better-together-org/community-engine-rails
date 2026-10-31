# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::AgreementRequirement: choosing which agreements buyers must
    # accept. Like the payment method settings, it works before any method is switched on, so a
    # steward can get the terms in order first.
    class AgreementRequirementPolicy < OwnerPolicy
      def index?  = manage_billing?
      def create? = manage_billing?
      def destroy? = manage_billing?
      def show? = false
      def update? = false

      # Requirements are visible once billing is configurable.
      class Scope < OwnerPolicy::Scope
        # Requirements belong to the platform (they have no seller of their own).
        def resolve
          platform = Current.platform
          return scope.none unless user && platform

          allowed = available?(platform) && user.permitted_to?(:manage_platform, platform)
          allowed ? scope.for_platform(platform) : scope.none
        end

        private

        def available?(platform) = BetterTogether::Billing.configurable?(platform)
      end

      private

      def billing_available?(owner) = BetterTogether::Billing.configurable?(owner)
    end
  end
end
