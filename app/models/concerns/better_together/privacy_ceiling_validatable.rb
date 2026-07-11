# frozen_string_literal: true

module BetterTogether
  # Validates that a record's privacy setting does not exceed the ceiling
  # imposed by its wrapping platform and community.
  #
  # Ceiling rules (most → most open: private → community → public):
  #   - Platform public + community public     → ceiling = 'public'
  #   - Platform public + community non-public → ceiling = 'community'
  #   - Platform non-public                    → ceiling = 'community'
  #
  # A private/non-public platform or community caps content at 'community'
  # (not 'private') because members of a locked-down platform or community
  # can still write community-scoped content.
  module PrivacyCeilingValidatable
    extend ActiveSupport::Concern

    CEILING_ORDER = %w[private community public].freeze

    included do
      validate :privacy_within_platform_community_bounds,
               if: -> { privacy.present? && (new_record? || will_save_change_to_privacy?) && !privacy_ceiling_exempt? }
    end

    # Escape hatch for models whose `privacy` value isn't actually used for
    # visibility gating (e.g. Agreement — its policy shows records to everyone
    # regardless of `privacy`) and so shouldn't be constrained by a platform's
    # or community's own privacy tier. Override to return true in such models.
    def privacy_ceiling_exempt?
      false
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
      wrapping_platform  = wrapping_privacy_ceiling_platform
      wrapping_community = wrapping_privacy_ceiling_community
      return nil unless wrapping_platform || wrapping_community
      return nil if external_wrapping_platform?(wrapping_platform)

      platform_idx  = ceiling_platform_level(wrapping_platform)
      community_idx = ceiling_community_level(wrapping_community)
      CEILING_ORDER[[platform_idx, community_idx].min]
    end

    def wrapping_privacy_ceiling_platform
      respond_to?(:platform) ? platform : nil
    end

    def wrapping_privacy_ceiling_community
      respond_to?(:community) ? community : nil
    end

    # External platforms (federation peers, OAuth identity providers) are
    # structural registry entries, not real local visibility containers, and
    # their auto-created primary community is a private placeholder (see
    # PrimaryCommunity#primary_community_privacy) rather than a real
    # community. Content whose platform is external (e.g. a mirrored
    # federated post) isn't locally contained, so no ceiling applies —
    # mirrors the exemption Platform itself gets via privacy_ceiling_exempt?.
    def external_wrapping_platform?(wrapping_platform)
      wrapping_platform.respond_to?(:external?) && wrapping_platform.external?
    end

    def ceiling_platform_level(platform)
      return CEILING_ORDER.length - 1 unless platform

      platform.privacy_public? ? CEILING_ORDER.length - 1 : CEILING_ORDER.index('community')
    end

    def ceiling_community_level(community)
      return CEILING_ORDER.length - 1 unless community

      community.privacy_public? ? CEILING_ORDER.length - 1 : CEILING_ORDER.index('community')
    end
  end
end
