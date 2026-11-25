# frozen_string_literal: true

namespace :better_together do
  namespace :communities do
    desc 'List communities whose creator holds no active membership; APPLY=1 grants each an explicit ' \
         'Organizer membership (silent). Dry run by default. Review the list before applying.'
    task backfill_creator_memberships: :environment do
      apply = ENV['APPLY'] == '1'
      entries = BetterTogether::Communities::CreatorMembershipBackfill.call(apply:)

      puts "#{apply ? 'APPLY' : 'DRY RUN'}: #{entries.size} community creator(s) without an active membership"
      entries.each do |e|
        puts [e.status, e.community_id, e.community_name.inspect, e.creator_name.inspect,
              "platform_manager=#{e.platform_manager}"].join("\t")
      end
      puts 'Nothing was changed. Re-run with APPLY=1 after review.' unless apply
    end
  end
end
