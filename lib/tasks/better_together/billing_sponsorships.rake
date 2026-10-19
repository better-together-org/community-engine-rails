# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  namespace :billing do
    namespace :sponsorships do
      desc 'Read-only report: Billing::Subscription rows still carrying the pre-redesign ' \
           'bt_beneficiary_type/bt_beneficiary_id metadata (a subscription whose real Stripe ' \
           'owner differs from who it was serving). Does not touch Stripe or write any data — ' \
           'ops review only. Each row needs case-by-case follow-up: the beneficiary now needs ' \
           'its own self-owned subscription/Sponsorship, funded via a monetary contribution, ' \
           'since sponsoring no longer swaps subscription ownership.'
      task detect_legacy_metadata_sponsorships: :environment do
        # rubocop:disable BetterTogether/NoRawSqlInQueries
        legacy = BetterTogether::Billing::Subscription
                 .where("metadata ? 'bt_beneficiary_type'")
                 .includes(:billing_plan, pay_subscription: :customer)
        # rubocop:enable BetterTogether/NoRawSqlInQueries

        if legacy.none?
          puts 'No legacy metadata-based sponsorships found.'
          next
        end

        puts "Found #{legacy.count} subscription(s) with legacy sponsorship metadata:\n\n"
        legacy.each do |subscription|
          real_owner = subscription.billable_owner
          legacy_beneficiary_type = subscription.metadata['bt_beneficiary_type']
          legacy_beneficiary_id = subscription.metadata['bt_beneficiary_id']
          legacy_beneficiary = BetterTogether::Billing::OwnershipResolver.resolve_record(
            legacy_beneficiary_type, legacy_beneficiary_id
          )

          puts "- Subscription #{subscription.id} (plan: #{subscription.billing_plan&.identifier})"
          puts "    real Stripe owner: #{real_owner.class.name} \"#{real_owner&.name}\" (#{real_owner&.id})"
          puts "    legacy beneficiary metadata: #{legacy_beneficiary_type} \"#{legacy_beneficiary&.name}\" (#{legacy_beneficiary_id})"
          puts '    needs manual follow-up: create the Sponsorship audit record and set up ' \
               "#{legacy_beneficiary&.name || legacy_beneficiary_id}'s own self-owned subscription/balance"
        end

        puts "\nThis task made no changes. See docs/plans (sponsorship redesign) for the manual follow-up procedure."
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
