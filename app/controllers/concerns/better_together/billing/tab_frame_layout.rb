# frozen_string_literal: true

module BetterTogether
  module Billing
    # The host billing page loads each billing screen into a lazy Turbo Frame tab (frame ids start with
    # billing-tab-). A request from one of those frames gets just the page content, wrapped in the frame it
    # asked for; every other request keeps the normal layout. Include it in any controller whose screen is
    # listed as a billing tab.
    module TabFrameLayout
      extend ActiveSupport::Concern

      TAB_FRAME_PREFIX = 'billing-tab-'

      private

      def determine_layout
        return 'better_together/billing_tab_frame' if billing_tab_frame_request?

        super
      end

      def billing_tab_frame_request?
        turbo_frame_request? && turbo_frame_request_id.to_s.start_with?(TAB_FRAME_PREFIX)
      end
    end
  end
end
