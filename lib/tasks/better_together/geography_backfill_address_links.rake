# frozen_string_literal: true

namespace :better_together do
  namespace :geography do
    desc 'Link existing addresses to the country/state/settlement records already resolved for them. ' \
         'Fills empty links only and never overwrites one. Safe to re-run.'
    task backfill_address_links: :environment do
      summary = BetterTogether::Geography::AddressLinkBackfill.call

      puts "Address geography link backfill complete: #{summary[:linked]} address(es) linked."
    end
  end
end
