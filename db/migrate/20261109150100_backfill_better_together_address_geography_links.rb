# frozen_string_literal: true

# Links existing addresses to their already-resolved geography records.
class BackfillBetterTogetherAddressGeographyLinks < ActiveRecord::Migration[7.2]
  def up
    run_engine_rake_task('better_together:geography:backfill_address_links', file: 'geography_backfill_address_links.rake',
                                                                             skip_when_empty: %i[better_together_addresses])
  end

  def down
    # Links are additive and harmless to keep.
  end
end
