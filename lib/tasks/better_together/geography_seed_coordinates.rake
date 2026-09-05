# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  namespace :geography do
    desc 'Maintainer-only, local/offline tool: geocodes GeographyBuilder\'s static seed-source ' \
         'data (continents/countries/provinces/regions/settlements) by name via live Nominatim, ' \
         'throttled to respect its usage policy, and writes the result to the committed ' \
         'lib/better_together/geography/seed_coordinates.yml packet. Never run in CI/production — ' \
         'this is a one-time/occasional generation step whose OUTPUT is what ships, not the task ' \
         'itself. Run again (e.g. after adding new seed-source entries) to fill in only the newly ' \
         'missing identifiers; pass FORCE=1 to regenerate every entry from scratch.'
    task generate_seed_coordinates: :environment do
      BetterTogether::Geography::SeedCoordinatesGenerator.call(force: ENV['FORCE'] == '1')
    end
  end
end
# rubocop:enable Metrics/BlockLength
