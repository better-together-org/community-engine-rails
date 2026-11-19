# frozen_string_literal: true

module BetterTogether
  module PlatformScoped # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      # optional: true + an explicit conditional validation (instead of the
      # required-by-default presence check belongs_to would add on its own)
      # so platform_presence_optional? is the single, overridable hook for an
      # includer that needs to skip it — belongs_to's auto-added validator is
      # NOT safely overridable by redeclaring belongs_to in a subclass: Rails'
      # presence validator is added once per declaration and accumulates
      # across the inheritance chain rather than being replaced, so a
      # subclass redeclaring belongs_to with optional: true ends up with both
      # the original required validator and the new one active simultaneously.
      belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true
      validates :platform, presence: true, unless: :platform_presence_optional?
      before_validation :assign_current_platform_if_available
      scope :for_platform, ->(platform) { where(platform:) }
    end

    class_methods do
      # Records of the given platform (else the current or host platform) plus records that
      # belong to no platform yet. Never another platform's records. With no platform at all
      # (bootstrap, rake tasks) nothing is there to isolate against and nothing is filtered.
      def in_current_platform(platform = nil)
        platform ||= Current.platform || Current.host_platform
        platform ? where(platform_id: [platform.id, nil]) : all
      end

      # friendly.find limited to one platform, so a slug, slug history entry or id owned by
      # another platform is not found. The platform's own record wins over a platform-less one.
      def friendly_find_in_platform(id, platform: nil)
        platform ||= Current.platform || Current.host_platform
        return friendly.find(id) unless platform

        for_platform(platform).friendly.find(id)
      rescue ActiveRecord::RecordNotFound
        raise unless platform

        where(platform_id: nil).friendly.find(id)
      end
    end

    # Platform presence is optional while the system has no platform at all —
    # i.e. before the very first Platform has been created. Every PlatformScoped
    # record created during that narrow bootstrap window (the host platform's own
    # primary community, its contact detail, its default calendar, seed-time
    # roles/permissions, etc.) has nowhere to resolve a platform from yet:
    # assign_current_platform_if_available's own fallback chain
    # (Current.platform -> host platform -> Platform.first) is exhausted, since
    # none of those exist either. Once any platform exists, this reverts to
    # false (platform required) for everyone, same as before this changed from
    # a hardcoded false — a model can still override this hook for a narrower
    # case, but the common bootstrap case no longer needs a per-model override.
    def platform_presence_optional?
      !BetterTogether::Platform.exists?
    end

    private

    def assign_current_platform_if_available
      return unless has_attribute?(:platform_id)
      return if platform_id.present?
      # A record bootstrapping as some platform's own primary community (or
      # that community's contact_detail/calendar) must not resolve to the
      # generic ambient platform (Current.platform / host platform /
      # Platform.first) meant for ordinary platform-scoped content created
      # within a request — it belongs to the platform being bootstrapped,
      # which PrimaryCommunity#backfill_primary_community_platform corrects
      # once that platform has a persisted id. See
      # Community#bootstrapping_host_community? /
      # #bootstrapping_primary_community for the two cases this covers.
      return if platform_presence_optional?

      resolved = Current.platform ||
                 BetterTogether::Platform.find_by(host: true) ||
                 BetterTogether::Platform.first
      self.platform = resolved if resolved
    end
  end
end
