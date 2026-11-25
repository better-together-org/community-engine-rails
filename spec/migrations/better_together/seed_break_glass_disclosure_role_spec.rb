# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261125015340_seed_break_glass_disclosure_role')

RSpec.describe SeedBreakGlassDisclosureRole do
  let(:migration) { described_class.new }
  let(:platform) { create(:better_together_platform, :public) }

  def role
    BetterTogether::Role.find_by(identifier: 'platform_disclosure_officer', platform_id: platform.id)
  end

  def permission
    BetterTogether::ResourcePermission.find_by(identifier: 'manage_break_glass_disclosure', platform_id: platform.id)
  end

  before do
    BetterTogether::AccessControlBuilder.seed_data(platform:)
    # Strip the break-glass records, as on an upgraded host app that predates them.
    BetterTogether::RoleResourcePermission.where(role_id: role&.id).delete_all
    BetterTogether::RoleResourcePermission.where(resource_permission_id: permission&.id).delete_all
    role&.delete
    permission&.delete
  end

  it 'adds the permission and the sealed role to the platform' do
    migration.up

    expect(permission).to be_present
    expect(role.resource_permissions.pluck(:identifier)).to contain_exactly('read_platform',
                                                                            'manage_break_glass_disclosure')
  end

  it 'gives the permission to no other role' do
    migration.up

    holders = BetterTogether::RoleResourcePermission.where(resource_permission_id: permission.id).pluck(:role_id)
    expect(holders).to eq([role.id])
  end

  it 'is idempotent' do
    migration.up

    expect { migration.up }.not_to(change { [BetterTogether::Role.count, BetterTogether::RoleResourcePermission.count] })
  end

  it 'removes the role and permission on the way down' do
    migration.up
    migration.down

    expect([role, permission]).to all(be_nil)
  end
end
