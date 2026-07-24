# frozen_string_literal: true

namespace :better_together do
  namespace :geography do
    desc 'One-time/admin-triggered import of boundary polygons from Nominatim for all seeded ' \
         'Continent/Country/State/Region/Settlement records missing a boundary. Rate-limited to ' \
         'respect Nominatim usage policy — run manually, never as part of routine deploys.'
    task import_boundaries: :environment do
      summary = BetterTogether::Geography::BoundaryImportJob.import_all_missing

      puts "Boundary import complete: #{summary[:imported]} fetched, #{summary[:skipped]} already had a boundary."
    end
  end
end
