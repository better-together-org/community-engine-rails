# frozen_string_literal: true

namespace :better_together do
  namespace :tenancy do
    desc 'Split users with memberships on several platforms into one account per platform. ' \
         'Dry run unless APPLY=1. Snapshot the database first (see docs/implementation/multi_tenancy).'
    task split_users: :environment do
      apply = ENV['APPLY'] == '1'
      plans = BetterTogether::UserPlatformSplitService.call(dry_run: !apply)
      puts "#{apply ? 'APPLIED' : 'DRY RUN'}: #{plans.size} account(s) to create"
      plans.each do |p|
        puts "#{p.status} user=#{p.user_id} -> platform=#{p.target_platform_id} " \
             "memberships=#{p.membership_ids.size} integrations=#{p.integration_ids.size}"
      end
      if apply
        failures = BetterTogether::UserPlatformSplitService.new.verification_failures
        abort "Verification failed for #{failures.size} membership(s)" if failures.any?
        puts 'Verification passed'
      end
    end
  end
end
