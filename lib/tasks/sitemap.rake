# frozen_string_literal: true

namespace :better_together do
  namespace :sitemap do
    desc 'Generate per-platform XML sitemaps for every locally-hosted platform and upload to Active Storage'
    task refresh: :environment do
      # Skip sitemap generation if the database is unavailable (e.g. during Docker builds)
      unless ActiveRecord::Base.connection.active?
        Rails.logger.warn 'Skipping sitemap generation: database connection not available'
        next
      end

      platforms = BetterTogether::Platform.internal
      if platforms.none?
        Rails.logger.warn 'Skipping sitemap generation: no locally-hosted platform configured'
        next
      end

      platforms.find_each do |platform|
        BetterTogether::Sitemaps::Generator.new(platform).call
        Rails.logger.info "Sitemap generated for platform #{platform.id} (#{platform.resolved_host_url})"
      rescue StandardError => e
        # One platform failing must not abort the sweep for the rest of the fleet.
        Rails.logger.error "Sitemap generation failed for platform #{platform.id}: #{e.message}"
      end
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error "Sitemap generation failed: #{e.message}"
    end
  end
end
