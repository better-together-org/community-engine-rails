# frozen_string_literal: true

module BetterTogether
  # Stores the generated sitemap in Active Storage for serving via S3
  class Sitemap < ApplicationRecord
    belongs_to :platform

    has_one_attached :file

    validates :locale, presence: true,
                       uniqueness: { scope: :platform_id },
                       inclusion: { in: ->(record) { available_locales(record) } }

    # Find or create sitemap for a specific platform and locale
    def self.current(platform, locale = I18n.locale)
      find_or_create_by!(platform: platform, locale: locale.to_s)
    end

    # Find or create sitemap index for a platform
    def self.current_index(platform)
      find_or_create_by!(platform: platform, locale: 'index')
    end

    # Available locale values (includes special 'index' locale)
    def self.available_locales(_record = nil)
      I18n.available_locales.map(&:to_s) + ['index']
    end
  end
end
