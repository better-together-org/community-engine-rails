# frozen_string_literal: true

module BetterTogether
  module PlatformScoped # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true
      before_validation :assign_current_platform_if_available
      scope :for_platform, ->(platform) { where(platform:) }
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
