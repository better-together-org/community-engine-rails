# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  namespace :geography do
    desc 'Installs the curated geography reference dataset (Continents/Countries/States/' \
         'Regions/Settlements) if not already present. Idempotent — safe to re-run. Does NOT ' \
         'geocode synchronously: each created record still enqueues a GeocodingJob (throttled by ' \
         'default queue processing, not this task) — run import_geocodes afterward to drain those. ' \
         'Run manually; not part of routine deploys/seeding.'
    task seed_reference_data: :environment do
      if BetterTogether::GeographyBuilder.seeded?
        puts 'Geography reference data already installed — nothing to do.'
      else
        BetterTogether::Geography::Geospatial::One.without_auto_geocoding do
          BetterTogether::GeographyBuilder.build_if_missing
        end
        puts 'Geography reference data installed. Run ' \
             '`better_together:geography:import_geocodes` next to geocode the new records.'
      end
    end

    desc 'One-time/admin-triggered geocoding of all Continent/Country/State/Region/Settlement ' \
         'records missing coordinates (GeographyBuilder seeds them with auto-geocoding suppressed ' \
         '— see Geospatial::One.without_auto_geocoding). Rate-limited to respect Nominatim usage ' \
         'policy (~1 request/sec in production) — a full run across all seeded levels takes on the ' \
         'order of several minutes. Run manually, never as part of routine deploys.'
    task import_geocodes: :environment do
      summary = BetterTogether::Geography::GeocodingJob.import_all_missing

      puts "Geocode import complete: #{summary[:imported]} geocoded, " \
           "#{summary[:skipped]} already had coordinates, #{summary[:failed]} failed."
    end
  end
end
# rubocop:enable Metrics/BlockLength
