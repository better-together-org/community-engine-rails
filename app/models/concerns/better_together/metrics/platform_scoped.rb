# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Adds the common tenant-platform association and scoping helper used by metrics records.
    module PlatformScoped
      extend ActiveSupport::Concern

      included do
        belongs_to :platform, class_name: 'BetterTogether::Platform'

        scope :for_platform, ->(platform) { where(platform:) }
      end
    end
  end
end
