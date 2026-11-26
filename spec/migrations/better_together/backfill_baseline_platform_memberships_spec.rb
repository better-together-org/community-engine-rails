# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261124171926_backfill_baseline_platform_memberships')

RSpec.describe BackfillBaselinePlatformMemberships do
  subject(:migration) { described_class.new }

  let(:platform) { configure_host_platform }
  let(:member_role) { BetterTogether::Role.find_default('platform_member', platform:) }

  # The user factory adds platform memberships itself; the backfill is for accounts that have none.
  def account_without_membership(platform:, confirmed: true)
    user = create(:better_together_user, :confirmed, platform:)
    user.update_column(:confirmed_at, nil) unless confirmed # rubocop:disable Rails/SkipsModelValidations
    BetterTogether::PersonPlatformMembership.where(member: user.person).delete_all
    user.person
  end

  def baseline(person, on: platform)
    on.person_platform_memberships.find_by(member: person, role: member_role)
  end

  before { platform }

  it 'gives an account without one the platform_member role on its own platform' do
    person = account_without_membership(platform:)

    migration.up

    expect(baseline(person)).to have_attributes(status: 'active', joinable: platform)
  end

  it 'leaves an unconfirmed account pending, as confirming the address then activates it' do
    person = account_without_membership(platform:, confirmed: false)

    migration.up

    expect(baseline(person)).to be_pending
  end

  it 'adds the baseline beside an elevated role without touching it' do
    person = account_without_membership(platform:)
    steward = BetterTogether::Role.find_default('platform_steward', platform:)
    platform.person_platform_memberships.create!(member: person, role: steward, status: 'active')

    migration.up

    expect(platform.person_platform_memberships.where(member: person).map { |m| m.role.identifier })
      .to contain_exactly('platform_steward', 'platform_member')
  end

  it 'is idempotent' do
    person = account_without_membership(platform:)

    migration.up

    expect { migration.up }.not_to(change { platform.person_platform_memberships.where(member: person).count })
  end

  it 'uses the role of the account platform on a second local platform' do
    other = create(:better_together_platform)
    other_role = BetterTogether::Role.find_default('platform_member', platform: other)
    person = account_without_membership(platform: other)

    migration.up

    expect(other.person_platform_memberships.find_by(member: person)).to have_attributes(role: other_role)
    expect(other_role).not_to eq(member_role)
  end

  it 'skips a platform that has no platform_member role rather than borrowing another platform\'s' do
    other = create(:better_together_platform)
    person = account_without_membership(platform: other)
    BetterTogether::Role.for_platform(other).delete_all

    migration.up

    expect(other.person_platform_memberships.where(member: person)).to be_empty
  end

  it 'skips remote platforms' do
    remote = create(:better_together_platform, :remote)
    person = account_without_membership(platform: remote)

    migration.up

    expect(remote.person_platform_memberships.where(member: person)).to be_empty
  end

  it 'ignores people with no account' do
    person = create(:better_together_person)

    migration.up

    expect(baseline(person)).to be_nil
  end

  it 'is not reversible' do
    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
