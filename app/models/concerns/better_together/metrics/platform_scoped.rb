# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Adds the common tenant-platform association and scoping helper used by metrics records.
    module PlatformScoped
      extend ActiveSupport::Concern

      included do
        belongs_to :platform, class_name: 'BetterTogether::Platform'
        before_validation :assign_platform_if_available

        scope :for_platform, ->(platform) { where(platform:) }
      end

      private

      def assign_platform_if_available
        return unless has_attribute?(:platform_id)
        return if platform_id.present?

        resolved = platform_from_parent_record ||
                   (Current.platform if Current.platform&.internal?)
        self.platform = resolved if resolved
      end

      def platform_from_parent_record
        parent = polymorphic_platform_parent
        return unless parent

        parent.platform if parent.respond_to?(:platform)
      end

      def polymorphic_platform_parent
        %i[pageable downloadable].each do |association_name|
          return public_send(association_name) if respond_to?(association_name) && public_send(association_name).present?
        end

        nil
      end
    end
  end
end
