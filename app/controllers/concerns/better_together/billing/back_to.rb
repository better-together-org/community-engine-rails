# frozen_string_literal: true

module BetterTogether
  module Billing
    # A billing detail page is reached from more than one screen (a list, the hub, another detail page), and some of
    # those load it inside a dashboard tab. Its back button returns to the screen the person came from, named in
    # `back_to`, so they never land in a different tab's frame. Only a billing screen of this site is accepted.
    module BackTo
      extend ActiveSupport::Concern

      included { helper_method :back_to_path }

      private

      def back_to_path(default)
        asked = params[:back_to].to_s
        local = asked.start_with?("/#{I18n.locale}/billing/") && !asked.include?('//') && !asked.include?('\\')
        local ? asked : default
      end
    end
  end
end
