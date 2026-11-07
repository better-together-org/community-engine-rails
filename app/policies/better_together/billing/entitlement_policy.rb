# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::Entitlement. A signed-in person looks at their own access; a steward who may
    # manage the platform's billing looks at the platform's allowances and usage. Nobody makes or changes an
    # entitlement through a screen: it follows what is paid.
    class EntitlementPolicy < OwnerPolicy
      def own? = user.present?
      def allowances? = manage_billing?
      def set_enforcement? = manage_billing?
      def index? = false
      def show? = false
      def create? = false
      def update? = false
      def destroy? = false
    end
  end
end
