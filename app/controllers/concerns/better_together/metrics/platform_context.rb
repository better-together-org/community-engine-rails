# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Resolves the current platform and authentication state for metrics writes and reads.
    module PlatformContext
      extend ActiveSupport::Concern

      private

      def metrics_platform
        Current.platform || BetterTogether::Platform.find_by(host: true)
      end

      def metrics_logged_in?
        current_user.present?
      end
    end
  end
end
