# frozen_string_literal: true

module BetterTogether
  # A gathering
  class Community < ApplicationRecord
    include Contactable
    include HostsEvents
    include Identifier
    include Infrastructure::BuildingConnections
    include Joinable
    include Permissible
    include PlatformHost
    include Protected
    include Privacy
    include Metrics::Viewable

    belongs_to :creator,
               class_name: '::BetterTogether::Person',
               optional: true

    has_many :calendars, class_name: 'BetterTogether::Calendar', dependent: :destroy
    has_one :default_calendar, -> { where(name: 'Default') }, class_name: 'BetterTogether::Calendar'

    joinable joinable_type: 'community',
             member_type: 'person'

    slugged :name

    translates :name, type: :string
    translates :description, type: :text
    translates :description_html, backend: :action_text

    has_one_attached :profile_image do |attachable|
      attachable.variant :optimized_jpeg, resize_to_limit: [200, 200],
                                          # rubocop:todo Layout/LineLength
                                          saver: { strip: true, quality: 90, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_png, resize_to_limit: [200, 200],
                                         saver: { strip: true, quality: 90, optimize_coding: true }, format: 'png'
    end

    has_one_attached :cover_image do |attachable|
      attachable.variant :optimized_jpeg, resize_to_limit: [2400, 600],
                                          # rubocop:todo Layout/LineLength
                                          saver: { strip: true, quality: 90, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_png, resize_to_limit: [2400, 600],
                                         saver: { strip: true, quality: 90, optimize_coding: true }, format: 'png'
    end

    has_one_attached :logo do |attachable|
      attachable.variant :optimized_jpeg, resize_to_limit: [200, 200],
                                          # rubocop:todo Layout/LineLength
                                          saver: { strip: true, quality: 90, interlace: true, optimize_coding: true, trellis_quant: true, quant_table: 3 }, format: 'jpg'
      # rubocop:enable Layout/LineLength
      attachable.variant :optimized_png, resize_to_limit: [200, 200],
                                         saver: { strip: true, quality: 90, optimize_coding: true }, format: 'png'
    end

    # Virtual attributes to track removal
    attr_accessor :remove_profile_image, :remove_cover_image, :remove_logo

    # Callbacks to remove images if necessary
    before_save :purge_profile_image, if: -> { remove_profile_image == '1' }
    before_save :purge_cover_image, if: -> { remove_cover_image == '1' }
    before_save :purge_logo, if: -> { remove_logo == '1' }
    after_create :create_default_calendar

    validates :name, presence: true

    def as_community
      becomes(self.class.base_class)
    end

    # Resize the cover image to specific dimensions
    def cover_image_variant(width, height)
      cover_image.variant(resize_to_fill: [width, height]).processed
    end

    def optimized_logo
      if logo.content_type == 'image/svg+xml'
        # If SVG, return the original without transformation
        logo

      # For other formats, analyze to determine transparency
      elsif logo.content_type == 'image/png'
        # If PNG with transparency, return the optimized PNG variant
        logo.variant(:optimized_png).processed
      else
        # Otherwise, use the optimized JPG variant
        logo.variant(:optimized_jpeg).processed
      end
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

    private

    def create_default_calendar
      # Ensure identifiers remain unique across calendars by namespacing with the community identifier
      calendars.create!(
        identifier: "default-#{identifier}",
        name: 'Default',
        description: I18n.t('better_together.calendars.default_description',
                            community_name: name,
                            default: 'Default calendar for %<community_name>s')
      )
    end

    include ::BetterTogether::RemoveableAttachment
  end
end
