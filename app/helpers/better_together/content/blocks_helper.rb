# frozen_string_literal: true

module BetterTogether
  module Content
    # Helpers for Content Blocks
    module BlocksHelper
      # Returns an array of acceptable image file types
      def acceptable_image_file_types
        BetterTogether::Content::Image::CONTENT_TYPES
      end

      # Helper to generate a unique temp_id for a model
      def temp_id_for(model, temp_id: SecureRandom.uuid)
        model.persisted? ? model.id : temp_id
      end
    end
  end
end
