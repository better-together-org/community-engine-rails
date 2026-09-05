# frozen_string_literal: true

module BetterTogether
  module FederationHub
    # Summarizes platform connection status/sync health for the Federation
    # Hub's admin section. Deliberately does not duplicate the full review
    # table already on the Host Dashboard's federation-review tab — this is
    # a glance-level summary that links out to it.
    class ConnectionHealthSummaryService
      def self.call(platform:)
        new(platform:).call
      end

      def initialize(platform:)
        @platform = platform
      end

      def call
        return default_summary unless platform

        {
          total_count: connections.size,
          pending_count: connections.count(&:pending?),
          active_count: connections.count(&:active?),
          healthy_count: connections.count(&:sync_healthy?),
          failed_count: connections.count(&:sync_failed?)
        }
      end

      private

      attr_reader :platform

      def connections
        @connections ||= ::BetterTogether::PlatformConnection
                         .includes(:source_platform, :target_platform)
                         .for_platform(platform)
                         .to_a
      end

      def default_summary
        { total_count: 0, pending_count: 0, active_count: 0, healthy_count: 0, failed_count: 0 }
      end
    end
  end
end
