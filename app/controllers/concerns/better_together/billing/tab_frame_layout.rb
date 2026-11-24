# frozen_string_literal: true

module BetterTogether
  module Billing
    # The host billing page loads each billing screen into a lazy Turbo Frame tab (frame ids start with
    # billing-tab-). A request from one of those frames gets just the page content, wrapped in the frame it
    # asked for; every other request keeps the normal layout. Include it in any controller whose screen is
    # listed as a billing tab.
    #
    # It also keeps a steward inside the billing page. A redirect made from inside a tab frame stays in that
    # frame. A redirect made outside one (the screen opened on its own, or a form sent without Turbo) that
    # lands on a billing tab's screen goes to the host billing page with that tab open and showing that screen.
    module TabFrameLayout
      extend ActiveSupport::Concern

      TAB_FRAME_PREFIX = 'billing-tab-'
      TAB_PANE_PREFIX = 'billing-pane-'

      def redirect_to(options = {}, response_options = {})
        super(billing_page_location(options), response_options)
      end

      private

      def determine_layout
        return 'better_together/billing_tab_frame' if billing_tab_frame_request?

        super
      end

      def billing_tab_frame_request?
        turbo_frame_request? && turbo_frame_request_id.to_s.start_with?(TAB_FRAME_PREFIX)
      end

      # The place a redirect should really go: the host billing page with the matching tab open, or the
      # location as given when it is not a tab's screen, or when the request is already inside a tab frame.
      def billing_page_location(options)
        return options unless options.is_a?(String) && !billing_tab_frame_request? && billing_page_available?

        tab_id, tab_path = billing_tab_for(URI.parse(options).path)
        return options unless tab_id

        screen = options unless options.split('?').first == tab_path
        better_together.host_dashboard_billing_path(locale: I18n.locale, billing_path: screen, anchor: "#{TAB_PANE_PREFIX}#{tab_id}")
      rescue URI::InvalidURIError
        options
      end

      def billing_tab_for(path)
        billing_tab_paths.find { |_, tab_path| path == tab_path || path.start_with?("#{tab_path}/") }
      end

      def billing_page_available?
        BetterTogether::HostDashboardPolicy.new(current_user, [:host_dashboard]).show?
      end

      # Tab identifier => the path of the screen it loads, for the host's billing menu.
      def billing_tab_paths
        @billing_tab_paths ||= billing_menu_items.to_h { |item| [item.identifier, billing_tab_path_for(item)] }
                                                 .compact.except(*billing_page_tab_ids)
      end

      def billing_menu_items
        menu = BetterTogether::NavigationItem.find_by(identifier: 'billing', navigation_area: helpers.platform_host_nav_area)
        menu ? menu.children.select { |item| item.route_name.present? } : []
      end

      # The menu's own entry for the billing page is not a tab.
      def billing_page_tab_ids
        billing_menu_items.select { |item| item.route_name == 'host_dashboard_billing_url' }.map(&:identifier)
      end

      def billing_tab_path_for(item)
        public_send(item.route_name.sub(/_url\z/, '_path'), locale: I18n.locale)
      rescue NoMethodError, ActionController::UrlGenerationError
        nil
      end
    end
  end
end
