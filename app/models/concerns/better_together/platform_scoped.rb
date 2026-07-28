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

      resolved = Current.platform ||
                 BetterTogether::Platform.find_by(host: true) ||
                 BetterTogether::Platform.first
      self.platform = resolved if resolved
    end
  end
end
