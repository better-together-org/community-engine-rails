# frozen_string_literal: true

module BetterTogether
  module Billing
    # Ties a billing record to exactly one platform, with no guessing.
    #
    # BetterTogether::PlatformScoped falls back to the host platform (and then
    # Platform.first) when it cannot tell which platform a record belongs to. For
    # billing that guess is a data leak: a job, webhook or console call has no
    # request, so the record would silently be filed under the host platform.
    # This concern only ever takes the platform from `Current.platform` (set per
    # web request, or explicitly by a caller that has a tenant in hand); anything
    # else must pass `platform:` itself, and a missing platform is a validation
    # error.
    #
    # The platform is also fixed once the record exists, so nothing can re-point
    # one tenant's record at another.
    module PlatformBound
      extend ActiveSupport::Concern

      included do
        belongs_to :platform, class_name: 'BetterTogether::Platform', optional: false

        attr_readonly :platform_id

        before_validation :assign_platform_from_current_context, on: :create
        validate :platform_unchanged, on: :update

        scope :for_platform, ->(platform) { where(platform:) }
      end

      private

      def assign_platform_from_current_context
        return if platform_id.present?

        self.platform = Current.platform if Current.platform.present?
      end

      def platform_unchanged
        return unless platform_id_changed?

        errors.add(:platform, :platform_readonly)
      end
    end
  end
end
