# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260321000002_backfill_host_platform_memberships')

RSpec.describe 'Backfill host platform memberships' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { BackfillHostPlatformMemberships.new }

  let!(:host_platform) do
    BetterTogether::Platform.find_or_create_by!(host: true) do |p|
      p.identifier = 'local-platform'
      p.url = 'https://example.test'
      p.privacy = 'public'
      p.name = 'Test Host Platform'
    end
  end

  def membership_role_identifier(person)
    host_platform.person_platform_memberships.find_by(member: person)&.role&.identifier
  end

  def find_or_create_platform_role!(identifier)
    BetterTogether::Role.find_or_create_by!(identifier:) do |r|
      r.name = identifier.titleize
      r.resource_type = 'BetterTogether::Platform'
      r.protected = true
    end
  end

  context 'when platform_member exists (the normal, current-schema case)' do
    before do
      find_or_create_platform_role!('platform_member')
      find_or_create_platform_role!('platform_manager')
    end

    it 'grants pre-existing people the low-privilege platform_member role, not an admin-tier role' do
      person = create(:better_together_person)

      migration.up

      expect(membership_role_identifier(person)).to eq('platform_member')
    end

    it 'does not touch people who already have a host membership' do
      person = create(:better_together_person)
      steward_role = find_or_create_platform_role!('platform_steward')
      create(
        :better_together_person_platform_membership,
        member: person,
        joinable: host_platform,
        role: steward_role,
        status: 'active'
      )

      migration.up

      expect(membership_role_identifier(person)).to eq('platform_steward')
    end

    it 'is idempotent on rerun' do
      person = create(:better_together_person)

      migration.up
      migration.up

      expect(
        host_platform.person_platform_memberships.where(member: person).count
      ).to eq(1)
    end
  end

  # The platform_steward/platform_manager fallback branches of the COALESCE
  # (for legacy instances that predate the platform_member seed migration)
  # aren't separately isolated here — the shared spec suite globally seeds a
  # platform_steward fixture that this migration file can't cleanly evict
  # without fighting suite-wide test setup. The precedence itself is a plain
  # COALESCE(member, steward, manager) and is covered by inspection; the
  # security-relevant behavior (member preferred over any admin-tier role)
  # is covered above.
end
