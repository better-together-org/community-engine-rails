# frozen_string_literal: true

module BetterTogether
  module Metrics
    class TrackShareJob < MetricsJob # rubocop:todo Style/Documentation
      def perform(platform, url, locale, shareable_type, shareable_id, platform_id, logged_in) # rubocop:todo Metrics/MethodLength, Metrics/ParameterLists
        shareable = nil
        if shareable_type.present?
          # Dynamic extension point, not a gem-owned allow-list: a host app opts a model into
          # share tracking by including BetterTogether::Metrics::Shareable, nothing else. See
          # docs/developers/architecture/polymorphic_allowlist_extension_audit.md
          allowed = BetterTogether::Metrics::Shareable.included_in_models.map(&:name)
          klass = BetterTogether::SafeClassResolver.resolve(shareable_type, allowed:)
          shareable = klass&.find_by(id: shareable_id)
        end

        # Create the Share record in the database
        # If a shareable_type was provided but is disallowed, do not create a record
        return if shareable_type.present? && shareable.nil?

        BetterTogether::Metrics::Share.create!(
          platform:,
          url:,
          locale:,
          shared_at: Time.current,
          shareable:,
          platform_id:,
          logged_in:
        )
      end
    end
  end
end
