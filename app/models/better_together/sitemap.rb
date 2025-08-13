# frozen_string_literal: true

module BetterTogether
  # Stores the generated sitemap in Active Storage for serving via S3
  class Sitemap < ApplicationRecord
    belongs_to :platform

    has_one_attached :file

    validates :platform_id, uniqueness: true

    def self.current(platform)
      find_or_create_by!(platform: platform)
    end
  end
end
