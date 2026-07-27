# frozen_string_literal: true

# Backfills the default map-tile CSP img_src origins (OpenStreetMap wildcard + bare host,
# Esri/ArcGIS satellite tiles — see ContentSecurityPolicySources::DEFAULT_MAP_TILE_IMG_SOURCES)
# onto any local platform missing one or more of them. Delegates to the idempotent rake task
# so the same repair can be re-run on demand (e.g. to correct production settings drift)
# without needing a follow-up migration each time.
class SeedDefaultLocalPlatformCspImageOrigins < ActiveRecord::Migration[7.1]
  def up
    return unless platforms_table_ready?

    puts 'Seeding default map-tile CSP img_src origins onto local platforms missing them...'

    load BetterTogether::Engine.root.join(
      'lib', 'tasks', 'better_together', 'seed_platform_csp_img_src_defaults.rake'
    )

    begin
      Rake::Task['better_together:seed:platform_csp_img_src_defaults'].invoke
    rescue RuntimeError
      Rake::Task['app:better_together:seed:platform_csp_img_src_defaults'].invoke
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Cannot safely distinguish auto-seeded default CSP origins from admin-configured ones'
  end

  private

  def platforms_table_ready?
    table_exists?(:better_together_platforms) &&
      column_exists?(:better_together_platforms, :settings) &&
      column_exists?(:better_together_platforms, :external)
  end
end
