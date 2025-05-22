# frozen_string_literal: true

module BetterTogether
  # A Schedulable Event
  class Event < ApplicationRecord
    include Creatable
    include FriendlySlug
    include Geography::Geospatial::One
    include Geography::Locatable::One
    include Identifier
    include Privacy
    include Viewable

    # belongs_to :address, -> { where(physical: true, primary_flag: true) }
    # accepts_nested_attributes_for :address, allow_destroy: true, reject_if: :blank?
    # delegate :geocoding_string, to: :address, allow_nil: true
    # geocoded_by :geocoding_string

    slugged :name

    translates :name
    translates :description, backend: :action_text

    has_one_attached :cover_image do |attachable|
      attachable.variant :optimized_jpeg, resize_to_limit: [2400, 1200],
                                          # rubocop:todo Layout/LineLength
                                          saver: { strip: true, quality: 85, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_png, resize_to_limit: [2400, 1200],
                                         saver: { strip: true, quality: 85, optimize_coding: true }, format: 'png'

      attachable.variant :optimized_card_jpeg, resize_to_limit: [1200, 300],
                                               # rubocop:todo Layout/LineLength
                                               saver: { strip: true, quality: 85, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_card_png, resize_to_limit: [1200, 300],
                                              saver: { strip: true, quality: 85, optimize_coding: true }, format: 'png'
    end

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
        starts_at ends_at
      ] + [
        {
          address_attributes: BetterTogether::Address.permitted_attributes(id: true)
        }
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

    def schedule_address_geocoding
      return unless should_geocode?

      BetterTogether::Geography::GeocodingJob.perform_later(self)
    end

    def should_geocode?
      return false if geocoding_string.blank?

      # space.reload # in case it has been geocoded since last load

      (address_changed? or !geocoded?)
    end

    def to_s
      name
    end

    include ::BetterTogether::RemoveableAttachment
  end
end
