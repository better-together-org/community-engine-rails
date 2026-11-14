# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackPageViewJob < MetricsJob # rubocop:todo Style/Documentation
      def perform(pageable, locale, platform_id = nil, logged_in = false) # rubocop:todo Style/OptionalBooleanParameter
        # Prefer the pageable's own platform (the real content owner) over the
        # viewer's current platform context — they can differ for federated/
        # cross-platform content, and the caller-supplied platform_id only reflects
        # who was browsing, not what they viewed.
        resolved_platform_id = pageable.try(:platform_id) || platform_id

        BetterTogether::Metrics::PageView.create!(
          pageable:,
          viewed_at: Time.current,
          locale:,
          platform_id: resolved_platform_id,
          logged_in:
        )
      end
    end
  end
end
