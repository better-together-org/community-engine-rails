# frozen_string_literal: true

require 'rails_helper'

require BetterTogether::Engine.root.join('db/migrate/20261117205154_seed_manage_platform_jobs_permission')

RSpec.describe SeedManagePlatformJobsPermission, :no_auth do
  let!(:host_platform) { configure_host_platform }
  let(:identifier) { 'manage_platform_jobs' }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.public_send(direction) }
  end

  def jobs_permission(platform = host_platform)
    BetterTogether::ResourcePermission.find_by(platform_id: platform.id, identifier:)
  end

  def holders(platform = host_platform)
    BetterTogether::Role.where(platform_id: platform.id)
                        .joins(:resource_permissions)
                        .where(better_together_resource_permissions: { identifier: })
                        .pluck(:identifier)
  end

  # The test database already has the packet planted; start from a host that predates the permission.
  def remove_jobs_permission
    migrate(:down)
  end

  before do
    remove_jobs_permission
    Rails.cache.clear
  end

  after { migrate(:up) } # leave the permission in place, as the seed packet does

  it 'does not require another migration file by its original name' do
    source = File.read(BetterTogether::Engine.root.join('db/migrate/20261117205154_seed_manage_platform_jobs_permission.rb'))

    expect(source).not_to match(/require(_relative)?\s+['"]\d{14}_/)
  end

  it 'adds the permission to the platform with its seeded attributes', :aggregate_failures do
    migrate(:up)

    permission = jobs_permission
    expect(permission).to be_present
    expect(permission.attributes.slice('action', 'target', 'resource_type', 'protected'))
      .to eq('action' => 'manage', 'target' => 'platform_jobs', 'resource_type' => 'BetterTogether::Platform',
             'protected' => true)
  end

  it 'grants it to every role holding manage_platform or manage_platform_settings', :aggregate_failures do
    custom = create(:better_together_role, :platform_role, platform: host_platform)
    custom.assign_resource_permissions(%w[manage_platform_settings])

    migrate(:up)

    expect(holders).to include('platform_steward', 'platform_manager', custom.identifier)
    expect(holders).not_to include('platform_member', 'platform_analytics_viewer')
  end

  it 'keeps access for a steward who could open Sidekiq before' do
    steward = create(:user, :confirmed)
    BetterTogether::PersonPlatformMembership.create!(joinable: host_platform, member: steward.person,
                                                     role: HostRoles.find!('platform_steward'), status: 'active')

    migrate(:up)
    Rails.cache.clear

    expect(BetterTogether::HostJobsPolicy.new(steward, :host_jobs).show?).to be true
  end

  it 'is idempotent', :aggregate_failures do
    migrate(:up)
    expect { migrate(:up) }.not_to(change { [BetterTogether::ResourcePermission.count, BetterTogether::RoleResourcePermission.count] })
  end

  it 'takes the next free position when 29 is used' do
    taken = BetterTogether::ResourcePermission.find_by(platform_id: host_platform.id, resource_type: 'BetterTogether::Platform',
                                                       position: 29)
    taken ||= create(:better_together_resource_permission, platform: host_platform, resource_type: 'BetterTogether::Platform',
                                                           position: 29)

    migrate(:up)

    expect(jobs_permission.position).to be > taken.position
  end

  it 'adds the permission to each other local platform from its own roles', :aggregate_failures do
    other = create(:better_together_platform, locality: 'local')
    BetterTogether::AccessControlBuilder.seed_data(platform: other)
    remove_jobs_permission
    expect(jobs_permission(other)).to be_nil

    migrate(:up)

    expect(jobs_permission(other)).to be_present
    expect(holders(other)).to include('platform_steward')
  end

  it 'removes the permission and its grants on rollback', :aggregate_failures do
    migrate(:up)
    permission_id = jobs_permission.id

    migrate(:down)

    expect(jobs_permission).to be_nil
    expect(BetterTogether::RoleResourcePermission.where(resource_permission_id: permission_id)).to be_empty
  end
end
