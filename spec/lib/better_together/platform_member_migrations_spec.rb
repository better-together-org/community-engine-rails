# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260320235959_seed_platform_member_role_before_host_backfill')
require BetterTogether::Engine.root.join('db/migrate/20260321000002_backfill_host_platform_memberships')

RSpec.describe 'Platform member security migrations' do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::Engine.routes.url_helpers

  let(:seed_migration) { SeedPlatformMemberRoleBeforeHostBackfill.new }
  let(:backfill_migration) { BackfillHostPlatformMemberships.new }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:read_platform_permission) { BetterTogether::ResourcePermission.find_by(identifier: 'read_platform') }
  let(:platform_member_role) { BetterTogether::Role.find_by(identifier: 'platform_member') }
  let(:platform_manager_role) do
    BetterTogether::Role.find_by(identifier: 'platform_steward') ||
      BetterTogether::Role.find_by(identifier: 'platform_manager')
  end

  before do
    BetterTogether::AccessControlBuilder.build(clear: false)
  end

  it 'creates the platform_member role and read_platform assignment idempotently' do
    if platform_member_role
      BetterTogether::RoleResourcePermission.where(role_id: platform_member_role.id).delete_all
      BetterTogether::Role.where(id: platform_member_role.id).delete_all
    end

    seed_migration.up

    created_role = BetterTogether::Role.find_by(identifier: 'platform_member')
    expect(created_role).to be_present
    expect(created_role.resource_type).to eq('BetterTogether::Platform')
    expect(created_role.slug).to eq('platform_member')
    expect(role_path(created_role, locale: I18n.default_locale)).to include('/roles/platform_member')

    assignment_scope = BetterTogether::RoleResourcePermission.where(
      role_id: created_role.id,
      resource_permission_id: read_platform_permission.id
    )
    expect(assignment_scope.count).to eq(1)

    expect { seed_migration.up }.not_to change(assignment_scope, :count)
  end

  it 'uses the next available platform role position when earlier slots are occupied' do
    if platform_member_role
      BetterTogether::RoleResourcePermission.where(role_id: platform_member_role.id).delete_all
      BetterTogether::Role.where(id: platform_member_role.id).delete_all
    end

    next_position = BetterTogether::Role.where(resource_type: 'BetterTogether::Platform').maximum(:position) + 1

    expect { seed_migration.up }.not_to raise_error

    created_role = BetterTogether::Role.find_by(identifier: 'platform_member')
    expect(created_role.position).to eq(next_position)
  end

  it 'uses the next available platform permission position when earlier slots are occupied' do
    existing_permission = BetterTogether::ResourcePermission.find_by(identifier: 'read_platform')
    if existing_permission
      BetterTogether::RoleResourcePermission.where(resource_permission_id: existing_permission.id).delete_all
      BetterTogether::ResourcePermission.where(id: existing_permission.id).delete_all
    end

    create(
      :better_together_resource_permission,
      identifier: 'existing_platform_permission',
      action: 'manage',
      target: 'platform',
      resource_type: 'BetterTogether::Platform',
      position: 1
    )

    next_position = BetterTogether::ResourcePermission.where(
      resource_type: 'BetterTogether::Platform'
    ).maximum(:position) + 1

    expect { seed_migration.up }.not_to raise_error

    created_permission = BetterTogether::ResourcePermission.find_by(identifier: 'read_platform')
    expect(created_permission.position).to eq(next_position)
  end

  it 'activates existing pending host-platform manager memberships' do
    manager_user = create(:better_together_user, :confirmed)
    membership = create(
      :better_together_person_platform_membership,
      joinable: host_platform,
      member: manager_user.person,
      role: platform_manager_role,
      status: 'pending'
    )

    seed_migration.up

    expect(membership.reload.status).to eq('active')
  end

  it 'backfills missing host-platform memberships as active platform_member memberships' do
    seed_migration.up
    legacy_user = create(:better_together_user, :confirmed)
    existing_membership = BetterTogether::PersonPlatformMembership.find_by(
      joinable: host_platform,
      member: legacy_user.person
    )

    expect(existing_membership).to be_nil

    backfill_migration.up

    membership = BetterTogether::PersonPlatformMembership.find_by(
      joinable: host_platform,
      member: legacy_user.person
    )

    expect(membership).to be_present
    expect(membership.status).to eq('active')
    expect(membership.role.identifier).to eq(platform_manager_role.identifier)
  end
end
