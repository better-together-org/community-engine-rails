# frozen_string_literal: true

require 'digest'

module BetterTogether
  module Metrics
    # Applies host/platform privacy settings before persisting search analytics.
    class SearchQueryCaptureService
      HASH_PREFIX = 'sha256:'

      def initialize(platform: Current.platform)
        @platform = platform if platform&.internal?
      end

      def call(query)
        normalized_query = normalize(query)
        return if normalized_query.blank?
        return unless analytics_enabled?

        analytics_mode == 'hashed' ? hashed_query(normalized_query) : normalized_query
      end

      private

      def analytics_enabled?
        return false if @platform.nil?

        @platform.search_query_analytics_enabled != false
      end

      def analytics_mode
        @platform&.search_query_analytics_mode || 'full'
      end

      def normalize(query)
        query.to_s.unicode_normalize(:nfkc).squish
      end

      def hashed_query(query)
        "#{HASH_PREFIX}#{Digest::SHA256.hexdigest(query.downcase)}"
      end
    end
  end
end
