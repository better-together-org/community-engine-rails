# frozen_string_literal: true

module BetterTogether
  # Robust content editing for the Community Engine
  module Content
    IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze

    CONTENT_TYPES = ([] + IMAGE_CONTENT_TYPES).freeze

    def self.table_name_prefix
      'better_together_content_'
    end
  end
end
