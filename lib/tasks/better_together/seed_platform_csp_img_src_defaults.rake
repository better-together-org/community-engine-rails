# frozen_string_literal: true

namespace :better_together do
  namespace :seed do
    desc 'Idempotently add the default map-tile CSP img_src origins to any local platform ' \
         'missing one or more of them (safe to re-run at any time)'
    task platform_csp_img_src_defaults: :environment do
      required_sources = BetterTogether::ContentSecurityPolicySources::DEFAULT_MAP_TILE_IMG_SOURCES
      updated_count = 0
      checked_count = 0

      BetterTogether::Platform.where(external: false).find_each do |platform|
        checked_count += 1
        settings = platform.settings.deep_dup
        existing_sources = Array(settings['csp_img_src']).map(&:to_s)
        missing_sources = required_sources - existing_sources

        next if missing_sources.empty?

        settings['csp_img_src'] = (existing_sources + missing_sources).uniq
        platform.update_columns(settings:, updated_at: Time.current)
        updated_count += 1

        puts "→ #{platform.identifier}: added #{missing_sources.join(', ')}"
      end

      puts "Done. #{updated_count}/#{checked_count} local platform(s) updated; " \
           "#{checked_count - updated_count} already had all default CSP img_src origins."
    end
  end
end
