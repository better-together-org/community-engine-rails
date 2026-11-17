# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261113200100_seed_manage_platform_code_permission')

RSpec.describe SeedManagePlatformCodePermission do
  let(:migration) { described_class.new }
  let(:platform_type) { 'BetterTogether::Platform' }

  before do
    BetterTogether::AccessControlBuilder.build(clear: false)
    remove_seeded_records
  end

  # The records are protected, so go around destroy the way the migration's own down step cannot.
  def remove_seeded_records
    role = BetterTogether::Role.find_by(identifier: 'platform_code_manager')
    permission = BetterTogether::ResourcePermission.find_by(identifier: 'manage_platform_code')
    BetterTogether::RoleResourcePermission.where(role_id: role&.id).delete_all
    BetterTogether::RoleResourcePermission.where(resource_permission_id: permission&.id).delete_all
    role&.delete
    permission&.delete
  end

  it 'takes the preferred positions when they are free' do
    BetterTogether::Role.where(resource_type: platform_type, position: 10).update_all(position: 5_000_000)
    BetterTogether::ResourcePermission.where(resource_type: platform_type, position: 28).update_all(position: 5_000_000)

    migration.up

    expect(BetterTogether::Role.find_by(identifier: 'platform_code_manager').position).to eq(10)
    expect(BetterTogether::ResourcePermission.find_by(identifier: 'manage_platform_code').position).to eq(28)
  end

  it 'takes the next free position when a host app role or permission already holds the preferred one' do
    BetterTogether::Role.where(resource_type: platform_type, position: 10).update_all(position: 5_000_000)
    BetterTogether::ResourcePermission.where(resource_type: platform_type, position: 28).update_all(position: 5_000_000)
    host_role = create(:better_together_role, resource_type: platform_type, position: 10)
    host_permission = create(:better_together_resource_permission, resource_type: platform_type, position: 28)

    expect { migration.up }.not_to raise_error

    role = BetterTogether::Role.find_by(identifier: 'platform_code_manager')
    permission = BetterTogether::ResourcePermission.find_by(identifier: 'manage_platform_code')
    expect(role.position).to be > host_role.position
    expect(permission.position).to be > host_permission.position
  end

  it 'keeps the position of records that already exist' do
    migration.up
    role = BetterTogether::Role.find_by(identifier: 'platform_code_manager')

    expect { migration.up }.not_to(change { role.reload.position })
  end
end
