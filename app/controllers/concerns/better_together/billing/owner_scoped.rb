# frozen_string_literal: true

module BetterTogether
  module Billing
    # Resolves the billing owner for a controller and keeps every lookup inside it.
    #
    # The owner is the current platform today. Controllers reach billing records only
    # through it (`billing_owner.billing_plans.find(id)`), never with a bare class-level
    # read, so one platform can never load another's record, whatever id is sent. When
    # communities manage their own plans, this is where a `community_id` is resolved.
    #
    # Billing off for the owner is a 404, before sign-in is asked for, so a platform that
    # has not set billing up does not reveal that the page exists. A signed-in steward of the host
    # platform gets the same 404 status with a page that says what is still to set up.
    module OwnerScoped
      extend ActiveSupport::Concern

      include TabFrameLayout

      included do
        before_action :require_billing_enabled
        before_action :authenticate_user!
        helper_method :billing_owner
      end

      private

      def billing_owner = Current.platform

      def require_billing_enabled
        return if billing_available?

        billing_steward? ? render_billing_not_enabled : render_not_found
      end

      def billing_steward?
        current_user.present? && billing_owner&.host? && BetterTogether::HostDashboardPolicy.new(current_user, [:host_dashboard]).show?
      end

      def render_billing_not_enabled
        @enablement = BetterTogether::Billing::Enablement.call(billing_owner)
        render 'better_together/billing/shared/not_enabled', status: :not_found
      end

      # Billing is on for the owner. A controller that has to work before any method is
      # enabled (the settings that turn the first one on) overrides this.
      def billing_available? = BetterTogether::Billing.enabled?(billing_owner)
    end
  end
end
