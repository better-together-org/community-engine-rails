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
    # has not set billing up does not reveal that the page exists.
    module OwnerScoped
      extend ActiveSupport::Concern

      included do
        before_action :require_billing_enabled
        before_action :authenticate_user!
        helper_method :billing_owner
      end

      # Frame id prefix of the billing tabs on the host billing page. A request from one of those
      # frames gets just the page content, wrapped in the frame it asked for.
      TAB_FRAME_PREFIX = 'billing-tab-'

      private

      def billing_owner = Current.platform

      def determine_layout
        return 'better_together/billing_tab_frame' if billing_tab_frame_request?

        super
      end

      def billing_tab_frame_request?
        turbo_frame_request? && turbo_frame_request_id.to_s.start_with?(TAB_FRAME_PREFIX)
      end

      def require_billing_enabled
        render_not_found unless billing_available?
      end

      # Billing is on for the owner. A controller that has to work before any method is
      # enabled (the settings that turn the first one on) overrides this.
      def billing_available? = BetterTogether::Billing.enabled?(billing_owner)
    end
  end
end
