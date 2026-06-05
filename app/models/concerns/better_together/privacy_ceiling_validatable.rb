# frozen_string_literal: true

module BetterTogether
  # Validates that a record's privacy setting does not exceed the ceiling
  # imposed by its wrapping platform and community.
  #
  # Ceiling rules (most → most open: private → community → public):
  #   - Platform non-public      → ceiling = platform.privacy
  #   - Platform public + community non-public → ceiling = 'community'
  #   - Platform public + community public     → ceiling = 'public'
  #
  # A private community caps content at 'community' (not 'private') because
  # members of a private community can still write community-scoped content.
  module PrivacyCeilingValidatable
    extend ActiveSupport::Concern

    CEILING_ORDER = %w[private community public].freeze

    included do
      validate :privacy_within_platform_community_bounds,
               if: -> { privacy.present? && (new_record? || will_save_change_to_privacy?) }
    end

    private

    def privacy_within_platform_community_bounds
      max = privacy_ceiling
      return unless max

      current_idx = CEILING_ORDER.index(privacy.to_s)
      max_idx     = CEILING_ORDER.index(max)
      return if current_idx.nil? || max_idx.nil? || current_idx <= max_idx

      default_msg = "cannot be more open than '#{max}' — platform or community settings prevent this"
      errors.add(:privacy, :exceeds_context_bounds,
                 message: I18n.t('better_together.errors.privacy.exceeds_context_bounds',
                                 max: max, default: default_msg))
    end

    def privacy_ceiling
      wrapping_platform  = respond_to?(:platform)  ? platform  : nil
      wrapping_community = respond_to?(:community) ? community : nil
      return nil unless wrapping_platform || wrapping_community

      platform_idx  = CEILING_ORDER.index(wrapping_platform&.privacy) || (CEILING_ORDER.length - 1)
      community_idx = ceiling_community_level(wrapping_community)
      CEILING_ORDER[[platform_idx, community_idx].min]
    end

    def ceiling_community_level(community)
      return CEILING_ORDER.length - 1 unless community

      community.privacy_public? ? CEILING_ORDER.length - 1 : CEILING_ORDER.index('community')
    end
  end
end
