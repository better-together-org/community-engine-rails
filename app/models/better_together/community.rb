# frozen_string_literal: true

module BetterTogether
  # A gathering
  class Community < ApplicationRecord
    include Contactable
    include Host
    include Identifier
    include Infrastructure::BuildingConnections
    include Joinable
    include Protected
    include Privacy
    include Permissible

    belongs_to :creator,
               class_name: '::BetterTogether::Person',
               optional: true

    joinable joinable_type: 'community',
             member_type: 'person'

    slugged :name

    translates :name
    translates :description, type: :text
    translates :description_html, backend: :action_text

    has_one_attached :profile_image do |attachable|
      attachable.variant :optimized_jpeg, resize_to_limit: [200, 200],
                                          # rubocop:todo Layout/LineLength
                                          saver: { strip: true, quality: 75, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_png, resize_to_limit: [200, 200],
                                         saver: { strip: true, quality: 75, optimize_coding: true }, format: 'png'
    end

    has_one_attached :cover_image do |attachable|
      attachable.variant :optimized_jpeg, resize_to_limit: [2400, 600],
                                          # rubocop:todo Layout/LineLength
                                          saver: { strip: true, quality: 75, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_png, resize_to_limit: [2400, 600],
                                         saver: { strip: true, quality: 75, optimize_coding: true }, format: 'png'
    end

    has_one_attached :logo do |attachable|
      attachable.variant :optimized_jpeg, resize_to_limit: [200, 200],
                                          # rubocop:todo Layout/LineLength
                                          saver: { strip: true, quality: 75, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_png, resize_to_limit: [200, 200],
                                         saver: { strip: true, quality: 75, optimize_coding: true }, format: 'png'
    end

    # Virtual attributes to track removal
    attr_accessor :remove_profile_image, :remove_cover_image, :remove_logo

    # Callbacks to remove images if necessary
    before_save :purge_profile_image, if: -> { remove_profile_image == '1' }
    before_save :purge_cover_image, if: -> { remove_cover_image == '1' }
    before_save :purge_logo, if: -> { remove_logo == '1' }

    validates :name, presence: true

    # Resize the cover image to specific dimensions
    def cover_image_variant(width, height)
      cover_image.variant(resize_to_fill: [width, height]).processed
    end

    def optimized_profile_image
      if profile_image.content_type == 'image/svg+xml'
        # If SVG, return the original without transformation
        profile_image

      # For other formats, analyze to determine transparency
      elsif profile_image.content_type == 'image/png'
        # If PNG with transparency, return the optimized PNG variant
        profile_image.variant(:optimized_png).processed
      else
        # Otherwise, use the optimized JPG variant
        profile_image.variant(:optimized_jpeg).processed
      end
    end

    def to_s
      name
    end

    include ::BetterTogether::RemoveableAttachment
  end
end
