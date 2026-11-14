# frozen_string_literal: true

module BetterTogether
  module Billing
    # Pundit policy for Billing::Event: the failed and dead-lettered webhook events a host
    # platform operator looks into and retries.
    #
    # Host platform only. Events come from the host's processor account, and a replay runs
    # that account's processor again, so another platform's steward has no business here.
    # Available once billing is configurable, so an operator can still reach it after the
    # last payment method was switched off.
    class EventPolicy < OwnerPolicy
      def index?  = operate?
      def show?   = operate?
      # Whether the event can be run again is the replay service's call, so a repeat request gets a reason.
      def replay? = operate?
      def create? = false
      def update? = false
      def destroy? = false

      # Only the current platform's own events, and only for a host platform operator.
      class Scope < OwnerPolicy::Scope
        def resolve
          platform = Current.platform
          return scope.none unless user && platform&.host?
          return scope.none unless available?(platform) && user.permitted_to?(:manage_platform, platform)

          scope.for_platform(platform)
        end

        private

        def available?(platform) = BetterTogether::Billing.configurable?(platform)
      end

      private

      def operate?
        owner = owner_for_record
        owner.respond_to?(:host?) && owner.host? && manage_billing?(owner)
      end

      def billing_available?(owner) = BetterTogether::Billing.configurable?(owner)
    end
  end
end
