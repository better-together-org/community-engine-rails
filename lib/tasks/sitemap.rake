# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :sitemap do
  desc 'Generate sitemap and upload to Active Storage'
  task refresh: :environment do
    # Skip sitemap generation if database is unavailable (e.g., during Docker builds)
    unless ActiveRecord::Base.connection.active?
      Rails.logger.warn 'Skipping sitemap generation: database connection not available'
      next
    end

    require 'sitemap_generator'

    SitemapGenerator::Sitemap.public_path = Rails.root.join('tmp')

    platform = BetterTogether::Platform.find_by(host: true)
    unless platform
      Rails.logger.warn 'Skipping sitemap generation: no host platform configured'
      next
    end

    load BetterTogether::Engine.root.join('config/sitemap.rb')

    # Attach locale-specific sitemaps
    I18n.available_locales.each do |locale|
      file_path = Rails.root.join('tmp', 'sitemaps', locale.to_s, 'sitemap.xml.gz')
      next unless File.exist?(file_path)

      sitemap_record = BetterTogether::Sitemap.find_or_initialize_by(platform: platform, locale: locale.to_s)
      File.open(file_path, 'rb') do |io|
        sitemap_record.attach_file_if_changed?(
          io: io,
          filename: "sitemap_#{locale}.xml.gz",
          content_type: 'application/gzip'
        )
      end
      sitemap_record.save!
    end

    # Attach sitemap index
    index_path = Rails.root.join('tmp', 'sitemap.xml.gz')
    if File.exist?(index_path)
      index_record = BetterTogether::Sitemap.find_or_initialize_by(platform: platform, locale: 'index')
      File.open(index_path, 'rb') do |io|
        index_record.attach_file_if_changed?(
          io: io,
          filename: 'sitemap_index.xml.gz',
          content_type: 'application/gzip'
        )
      end
      index_record.save!
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error "Sitemap generation failed: #{e.message}"
  end
end
# rubocop:enable Metrics/BlockLength
