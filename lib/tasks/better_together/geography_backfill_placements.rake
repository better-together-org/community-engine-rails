# frozen_string_literal: true

namespace :better_together do
  namespace :geography do
    desc 'Enqueue HierarchyResolutionJob for existing geocoded Address/Building/Event (or any ' \
         'Geography::Locatable::Many includer) records with no resolved geography placement yet. ' \
         'Safe to re-run. Run this after better_together:geography:import_boundaries has populated ' \
         'at least Country/Continent boundaries — Region/Settlement will mostly stay unresolved ' \
         'given the current sparse NL-only seed data, which is expected.'
    task backfill_placements: :environment do
      summary = BetterTogether::Geography::HierarchyResolutionJob.backfill_all_missing

      puts "Geography placement backfill complete: #{summary[:enqueued]} record(s) enqueued."
    end
  end
end
