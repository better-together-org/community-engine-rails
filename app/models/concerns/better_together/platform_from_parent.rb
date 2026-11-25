# frozen_string_literal: true

module BetterTogether
  # Keeps a child record on its parent's platform: fills platform_id from the parent when blank and
  # rejects a platform that differs from the parent's. Include after Identifier so it runs first.
  module PlatformFromParent
    extend ActiveSupport::Concern

    class_methods do
      def platform_from(parent_name)
        define_method(:platform_parent) { public_send(parent_name) }
        before_validation :assign_platform_from_parent, prepend: true
        validate :platform_matches_parent
      end
    end

    private

    def assign_platform_from_parent
      return if platform_id.present? || platform.present?

      self.platform = platform_parent&.platform
    end

    def platform_matches_parent
      parent_platform_id = platform_parent&.platform_id
      return if parent_platform_id.blank? || platform_id.blank? || platform_id == parent_platform_id

      errors.add(:platform, :invalid)
    end
  end
end
