# frozen_string_literal: true

module BetterTogether
  module PlatformScoped # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      # optional: true + an explicit conditional validation (instead of the
      # required-by-default presence check belongs_to would add on its own)
      # so platform_presence_optional? is the single, overridable hook for the
      # rare includer that needs to skip it (see Community/ContactDetail,
      # which do so only for the bootstrapping host platform's own primary
      # community — belongs_to's auto-added validator is NOT safely
      # overridable by redeclaring belongs_to in a subclass: Rails' presence
      # validator is added once per declaration and accumulates across the
      # inheritance chain rather than being replaced, so a subclass
      # redeclaring belongs_to with optional: true ends up with both the
      # original required validator and the new one active simultaneously).
      belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true
      validates :platform, presence: true, unless: :platform_presence_optional?
      before_validation :assign_current_platform_if_available
      scope :for_platform, ->(platform) { where(platform:) }
    end

    # Hook for the rare includer that must be able to save without a platform
    # in some narrow, well-defined case. False (platform required, matching
    # the pre-existing required-by-default behavior) for every includer that
    # doesn't override this.
    def platform_presence_optional?
      false
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
