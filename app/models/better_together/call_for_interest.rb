module BetterTogether
  class CallForInterest < ApplicationRecord
    self.table_name = :better_together_calls_for_interest

    include Creatable
    include Identifier
    include Privacy

    translates :name
    translates :description, backend: :action_text

    slugged :name

    belongs_to :interestable, polymorphic: true, optional: true

    has_one_attached :cover_image do |attachable|
      attachable.variant :optimized_jpeg, resize_to_limit: [2400, 1200],
                                          # rubocop:todo Layout/LineLength
                                          saver: { strip: true, quality: 85, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_png, resize_to_limit: [2400, 1200],
                                         saver: { strip: true, quality: 85, optimize_coding: true }, format: 'png'

      attachable.variant :optimized_card_jpeg, resize_to_limit: [1200, 300],
                                               # rubocop:todo Layout/LineLength
                                               saver: { strip: true, quality: 90, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_card_png, resize_to_limit: [1200, 300],
                                              saver: { strip: true, quality: 90, optimize_coding: true }, format: 'png'
    end

    CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/svg+xml].freeze

    validates :cover_image,
              content_type: CONTENT_TYPES,
              size: { less_than: 100.megabytes, message: 'is too large' }

    alias card_image cover_image

    attr_accessor :remove_cover_image

    before_save :purge_cover_image, if: -> { remove_cover_image == '1' }

    scope :draft, lambda {
      start_query = arel_table[:starts_at].eq(nil)
      where(start_query)
    }

    scope :upcoming, lambda {
      start_query = arel_table[:starts_at].gteq(DateTime.now)
      where(start_query)
    }

    scope :past, lambda {
      start_query = arel_table[:starts_at].lt(DateTime.now)
      where(start_query)
    }

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        type starts_at ends_at
      ]
    end

    def optimized_card_image
      if card_image.content_type == 'image/svg+xml'
        # If SVG, return the original without transformation
        card_image

      # For other formats, analyze to determine transparency
      elsif card_image.content_type == 'image/png'
        # If PNG with transparency, return the optimized PNG variant
        card_image.variant(:optimized_card_png).processed
      else
        # Otherwise, use the optimized JPG variant
        card_image.variant(:optimized_card_jpeg).processed
      end
    end

    def optimized_cover_image
      if cover_image.content_type == 'image/svg+xml'
        # If SVG, return the original without transformation
        cover_image

      # For other formats, analyze to determine transparency
      elsif cover_image.content_type == 'image/png'
        # If PNG with transparency, return the optimized PNG variant
        cover_image.variant(:optimized_png).processed
      else
        # Otherwise, use the optimized JPG variant
        cover_image.variant(:optimized_jpeg).processed
      end
    end

    include ::BetterTogether::RemoveableAttachment
  end
end
