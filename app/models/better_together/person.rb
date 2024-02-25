# frozen_string_literal: true

module BetterTogether
  # A human being
  class Person < ApplicationRecord
    include AuthorConcern
    include FriendlySlug
    include Identity

    slugged :name, slug_column: :handle

    # has_one_attached :profile_image

    validates :name,
              presence: true

    # validate :validate_profile_image

    def to_s
      name
    end

    # def validate_profile_image
    #   return unless profile_image.attached?

    #   if profile_image.blob.byte_size > 5.megabytes
    #     errors.add(:profile_image, 'is too large (maximum is 5MB)')
    #   elsif !profile_image.blob.content_type.starts_with?('image/')
    #     errors.add(:profile_image, 'is not an image')
    #   else
    #     validate_image_dimensions
    #   end
    # end

    # def validate_image_dimensions
    #   return unless Object.const_defined?('MiniMagick')

    #   image = MiniMagick::Image.open(profile_image.blob.service_url)
    #   if image.width > 3000 || image.height > 3000
    #     errors.add(:profile_image, 'dimensions are too large (maximum is 3000x3000 pixels)')
    #   end
    # end
  end
end
