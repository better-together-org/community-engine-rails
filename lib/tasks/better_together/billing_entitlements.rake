# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  namespace :billing do
    namespace :entitlements do
      desc 'Backfill Billing::Entitlement rows for existing access_active hosted subscriptions, ' \
           "so entitled_to?('hosted_access', ...) is correct for pre-existing subscribers without " \
           "waiting on each one's next Stripe webhook sync. Set DRY_RUN=true to report without writing."
      task backfill_hosted_access: :environment do
        dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', nil))
        eligible_subscriptions = BetterTogether::Billing::Subscription
                                 .includes(:billing_plan, pay_subscription: :customer)
                                 .select do |subscription|
                                   subscription.billing_plan&.granted_entitlement_keys&.include?('hosted_access') &&
                                     subscription.access_active?
                                 end

        puts "Found #{eligible_subscriptions.count} access_active subscription(s) whose plan grants hosted_access."

        eligible_subscriptions.each do |subscription|
          owner = subscription.billable_owner
          next if owner.blank?

          if dry_run
            puts "- [dry run] would grant hosted_access to #{owner.class.name} \"#{owner.name}\" (#{owner.id})"
          else
            BetterTogether::Billing::EntitlementGrantSync.new.call(
              billable_owner: owner, billing_plan: subscription.billing_plan, source: subscription
            )
            puts "- granted hosted_access to #{owner.class.name} \"#{owner.name}\" (#{owner.id})"
          end
        end

        puts(dry_run ? "\nDry run only — no changes were made." : "\nDone.")
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
