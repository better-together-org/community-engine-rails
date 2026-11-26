# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::ProcessorSetting: turning payment methods on and off.
    #
    # Unlike plans, it needs billing to be configurable, not already enabled: the first method
    # has to be switched on from this page.
    class ProcessorSettingPolicy < OwnerPolicy
      def index?  = manage_billing?
      def edit?   = manage_billing?
      def update? = manage_billing?
      def show?   = manage_billing?
      def destroy? = false

      # Settings are visible once billing is configurable, not only once a method is on.
      class Scope < OwnerPolicy::Scope
        private

        def available?(platform) = BetterTogether::Billing.configurable?(platform)
      end

      private

      def billing_available?(owner) = BetterTogether::Billing.configurable?(owner)
    end
  end
end
