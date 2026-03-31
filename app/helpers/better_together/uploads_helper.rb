# frozen_string_literal: true

module BetterTogether
  # helper methods for file uploads
  module UploadsHelper
    def total_upload_size(uploads)
      number_to_human_size(uploads.sum(&:byte_size))
    end
  end
end
