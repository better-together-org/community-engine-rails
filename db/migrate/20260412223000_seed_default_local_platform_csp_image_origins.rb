# frozen_string_literal: true

class SeedDefaultLocalPlatformCspImageOrigins < ActiveRecord::Migration[7.1]
  class MigrationPlatform < ActiveRecord::Base
    self.table_name = 'better_together_platforms'
  end

  DEFAULT_CSP_IMG_SOURCES = [
    'https://unpkg.com',
    'https://*.tile.openstreetmap.org'
  ].freeze

  def up
    return unless platforms_table_ready?

    migrate_local_platforms do |settings|
      settings['csp_img_src'] = merge_sources(settings['csp_img_src'], DEFAULT_CSP_IMG_SOURCES)
      settings
    end
  end

  def down
    return unless platforms_table_ready?

    migrate_local_platforms do |settings|
      updated_sources = normalize_sources(settings['csp_img_src']) - DEFAULT_CSP_IMG_SOURCES

      if updated_sources.empty?
        settings.delete('csp_img_src')
      else
        settings['csp_img_src'] = updated_sources
      end

      settings
    end
  end

  private

  def platforms_table_ready?
    table_exists?(:better_together_platforms) &&
      column_exists?(:better_together_platforms, :settings) &&
      column_exists?(:better_together_platforms, :external)
  end

  def migrate_local_platforms
    MigrationPlatform.reset_column_information

    MigrationPlatform.where(external: false).find_each do |platform|
      settings = normalized_settings(platform.settings)
      updated_settings = yield(settings.deep_dup)
      next if updated_settings == settings

      platform.update_columns(settings: updated_settings, updated_at: Time.current)
    end
  end

  def normalized_settings(raw_settings)
    raw_settings.is_a?(Hash) ? raw_settings.deep_dup : {}
  end

  def merge_sources(existing_sources, additional_sources)
    (normalize_sources(existing_sources) + normalize_sources(additional_sources)).uniq
  end

  def normalize_sources(values)
    Array(values).map(&:to_s).map(&:strip).reject(&:empty?).uniq
  end
end
