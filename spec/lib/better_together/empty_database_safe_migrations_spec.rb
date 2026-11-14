# frozen_string_literal: true

require 'rails_helper'

%w[
  20250330131445_delete_existing_twix_social_media_accounts
  20251218230553_recalculate_event_end_times
  20251219201017_seed_rbac_and_navigation
  20251229000000_add_posts_navigation_items
  20260117124817_add_timezone_to_events
].each { |name| require BetterTogether::Engine.root.join('db/migrate', name) }

# These older migrations must also run from zero on an empty database, so they use plain SQL
# or migration-local models and guard on schema/data instead of loading app models or rake tasks.
RSpec.describe 'Empty-database-safe older migrations' do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  let(:connection) { ActiveRecord::Base.connection }

  def run_up(klass)
    migration = klass.new
    migration.verbose = false
    migration.up
  end

  it 'deletes Twitter and X accounts without the platform scoped app model' do
    table = DeleteExistingTwixSocialMediaAccounts::MigrationSocialMediaAccount
    expect(table.table_name).to eq('better_together_social_media_accounts')
    expect { run_up(DeleteExistingTwixSocialMediaAccounts) }.not_to raise_error
  end

  it 'fills missing event end times in SQL and is idempotent' do
    event = create(:event, starts_at: 1.day.from_now, duration_minutes: 90)
    BetterTogether::Event.where(id: event.id).update_all(ends_at: nil) # rubocop:disable Rails/SkipsModelValidations

    2.times { run_up(RecalculateEventEndTimes) }

    expect(event.reload.ends_at).to be_within(1.second).of(event.starts_at + 90.minutes)
  end

  it 'skips the RBAC and navigation seeding when the database has no roles yet' do
    migration = SeedRbacAndNavigation.new
    migration.verbose = false
    allow(migration).to receive(:select_value).and_return(nil)

    expect { migration.up }.not_to(change { [BetterTogether::NavigationItem.count, BetterTogether::Role.count] })
  end

  it 'skips the posts navigation items when there are no navigation areas yet' do
    migration = AddPostsNavigationItems.new
    migration.verbose = false
    allow(migration).to receive(:select_value).and_return(nil)

    expect { migration.up }.not_to change(BetterTogether::NavigationArea, :count)
  end

  it 'backfills the event timezone from the host platform and tolerates a re-run' do
    platform = configure_host_platform
    event = create(:event)
    platform.update_column(:time_zone, 'America/St_Johns') # rubocop:disable Rails/SkipsModelValidations
    BetterTogether::Event.where(id: event.id).update_all(timezone: 'UTC') # rubocop:disable Rails/SkipsModelValidations

    2.times { run_up(AddTimezoneToEvents) }

    expect(event.reload.timezone).to eq('America/St_Johns')
  end
end
