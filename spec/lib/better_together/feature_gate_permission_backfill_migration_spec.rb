# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260522123000_backfill_feature_gate_permissions')

RSpec.describe 'Feature gate permission backfill migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { BackfillFeatureGatePermissions.new }

  before do
    BetterTogether::AccessControlBuilder.build(clear: false)
  end

  it 'creates the feature permissions and assigns them idempotently' do
    BetterTogether::RoleResourcePermission.joins(:resource_permission)
                                          .where(better_together_resource_permissions: { identifier: %w[access_beta_features
                                                                                                        access_alpha_features] })
                                          .delete_all
    BetterTogether::ResourcePermission.where(identifier: %w[access_beta_features access_alpha_features]).delete_all

    migration.up

    beta_permission = BetterTogether::ResourcePermission.find_by(identifier: 'access_beta_features')
    alpha_permission = BetterTogether::ResourcePermission.find_by(identifier: 'access_alpha_features')

    expect(beta_permission).to be_present
    expect(alpha_permission).to be_present
    expect(
      BetterTogether::RoleResourcePermission.where(resource_permission: beta_permission).count
    ).to be >= 1

    expect { migration.up }.not_to(change do
      BetterTogether::RoleResourcePermission.where(resource_permission: beta_permission).count
    end)
  end

  it 'removes the seeded role assignments on down without deleting the permissions' do
    migration.up
    beta_permission = BetterTogether::ResourcePermission.find_by(identifier: 'access_beta_features')

    expect(beta_permission).to be_present
    expect(BetterTogether::RoleResourcePermission.where(resource_permission: beta_permission)).not_to be_empty

    migration.down

    expect(BetterTogether::ResourcePermission.find_by(identifier: 'access_beta_features')).to be_present
    expect(BetterTogether::RoleResourcePermission.where(resource_permission: beta_permission)).to be_empty
  end
end
