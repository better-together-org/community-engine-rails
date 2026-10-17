# frozen_string_literal: true

namespace :better_together do
  namespace :geography do
    desc 'One-time/admin-triggered import of boundary polygons from Nominatim for seeded ' \
         'Continent/Country/State/Region/Settlement records missing a boundary. Rate-limited to ' \
         'respect Nominatim usage policy - run manually, never as part of routine deploys. ' \
         'Options (environment): LEVEL=settlement[,region] IDENTIFIER=corner-brook[,...] FORCE=1 (refetch, and retry ' \
         'records remembered as having no polygon) DRY_RUN=1 THRESHOLD=0.0005 (polygon simplification, degrees).'
    task import_boundaries: :environment do
      list = ->(key) { ENV[key].to_s.split(',').map(&:strip).compact_blank.presence }
      summary = BetterTogether::Geography::BoundaryImportJob.import_all_missing(
        levels: list.call('LEVEL'), identifiers: list.call('IDENTIFIER'),
        force: ENV['FORCE'].present?, dry_run: ENV['DRY_RUN'].present?,
        threshold: ENV['THRESHOLD'].presence&.to_f
      )

      if ENV['DRY_RUN'].present?
        puts "Dry run: #{summary[:planned].size} record(s) would be fetched"
        summary[:planned].each { |entry| puts "  #{entry}" }
      else
        puts "Boundary import complete: #{summary[:imported]} fetched, #{summary[:skipped]} already had a boundary, " \
             "#{summary[:skipped_known_missing]} remembered as having no polygon, " \
             "#{summary[:unsupported] || 0} had no usable boundary data, #{summary[:failed] || 0} failed."
      end
    end
  end
end
