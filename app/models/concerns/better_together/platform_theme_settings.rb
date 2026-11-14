# frozen_string_literal: true

module BetterTogether
  # Theme settings for a platform: colour/font/radius tokens kept in settings['theme'],
  # a header banner and favicon, and the site logo delegated to the platform's community.
  module PlatformThemeSettings
    extend ActiveSupport::Concern

    FAVICON_TYPES = %w[image/png image/svg+xml image/vnd.microsoft.icon image/webp].freeze

    included do
      has_one_attached :header_banner
      has_one_attached :favicon
      has_one_attached :dark_logo

      attr_accessor :remove_header_banner, :remove_favicon, :remove_logo, :remove_dark_logo

      validates :header_banner, content_type: BetterTogether::Attachments::Images::VALID_IMAGE_CONTENT_TYPES,
                                size: { less_than: 20.megabytes }
      validates :dark_logo, content_type: BetterTogether::Attachments::Images::VALID_IMAGE_CONTENT_TYPES,
                            size: { less_than: 20.megabytes }
      validates :favicon, content_type: FAVICON_TYPES, size: { less_than: 1.megabyte }
      validate :theme_values_are_valid

      before_save :purge_header_banner, if: -> { remove_header_banner == '1' }
      before_save :purge_dark_logo, if: -> { remove_dark_logo == '1' }
      before_save :purge_favicon, if: -> { remove_favicon == '1' }
      after_save :apply_logo_to_community
    end

    def theme_config
      BetterTogether::PlatformThemeConfig.new((settings || {})['theme'])
    end

    # Accepts the form's theme hash; blank values clear a token.
    def theme=(raw)
      self.settings = (settings || {}).merge('theme' => BetterTogether::PlatformThemeConfig.sanitize(raw))
    end

    def theme
      theme_config.values
    end

    def logo
      community&.logo
    end

    def logo=(file)
      @pending_logo = file if file.present?
    end

    private

    def purge_header_banner = header_banner.purge_later

    def purge_favicon = favicon.purge_later

    def purge_dark_logo = dark_logo.purge_later

    def theme_values_are_valid
      bad = BetterTogether::PlatformThemeConfig.errors_for(theme).map(&:first)
      bad.each { |key| errors.add(:theme, :invalid_value, key:) }
    end

    def apply_logo_to_community
      return if community.blank?

      community.remove_logo = remove_logo if remove_logo == '1'
      community.logo.attach(@pending_logo) if @pending_logo
      community.save! if remove_logo == '1' || @pending_logo
      @pending_logo = nil
    end
  end
end
