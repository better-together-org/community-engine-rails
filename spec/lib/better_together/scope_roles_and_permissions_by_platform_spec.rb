# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261116120000_scope_roles_and_permissions_by_platform')

RSpec.describe ScopeRolesAndPermissionsByPlatform do # rubocop:disable RSpec/DescribeClass
  let(:migration) { described_class.new }
  let(:host) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:other) { create(:better_together_platform, host: false, locality: 'local') }

  before do
    host
    BetterTogether::AccessControlBuilder.seed_data(platform: host)
    other
  end

  def silently(&)
    ActiveRecord::Migration.suppress_messages(&)
  end

  it 'gives each non-host platform its own copy of roles, permissions, assignments and names' do
    silently { migration.up }

    host_roles = BetterTogether::Role.where(platform_id: host.id)
    copied = BetterTogether::Role.where(platform_id: other.id)
    expect(copied.pluck(:identifier)).to match_array(host_roles.pluck(:identifier))
    expect(copied.pluck(:id) & host_roles.pluck(:id)).to be_empty
    expect(copied.find_by(identifier: 'community_organizer').name).to eq('Community Organizer')
    expect(BetterTogether::ResourcePermission.where(platform_id: other.id).count)
      .to eq(BetterTogether::ResourcePermission.where(platform_id: host.id).count)
    expect(BetterTogether::RoleResourcePermission.where(platform_id: other.id).count)
      .to eq(BetterTogether::RoleResourcePermission.where(platform_id: host.id).count)
  end

  it 'repoints platform memberships to the role copy for their own platform' do
    old_role = BetterTogether::Role.find_by!(platform_id: host.id, identifier: 'platform_manager')
    person = create(:better_together_person)
    BetterTogether::PersonPlatformMembership.where(joinable: other, member: person)
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO better_together_person_platform_memberships (id, member_id, joinable_id, role_id, status, created_at, updated_at, lock_version)
      VALUES (gen_random_uuid(), #{ActiveRecord::Base.connection.quote(person.id)}, #{ActiveRecord::Base.connection.quote(other.id)},
              #{ActiveRecord::Base.connection.quote(old_role.id)}, 'active', NOW(), NOW(), 0)
    SQL

    silently { migration.up }

    membership = BetterTogether::PersonPlatformMembership.find_by!(joinable_id: other.id, member_id: person.id)
    expect(membership.role.platform_id).to eq(other.id)
    expect(membership.role.identifier).to eq('platform_manager')
  end

  it 'backfills the platform of slug history rows for roles and permissions', :aggregate_failures do
    role = BetterTogether::Role.find_by!(platform_id: host.id, identifier: 'platform_manager')
    permission = BetterTogether::ResourcePermission.find_by!(platform_id: host.id)
    slugs = FriendlyId::Slug.unscoped.where(sluggable_id: [role.id, permission.id])
    slugs.update_all(platform_id: nil) # rubocop:disable Rails/SkipsModelValidations

    silently { migration.up }

    expect(slugs.reload.pluck(:platform_id).uniq).to eq([host.id])
  end

  it 'leaves a slug row alone when its platform already holds the same slug' do
    role = BetterTogether::Role.find_by!(platform_id: host.id, identifier: 'platform_manager')
    row = FriendlyId::Slug.unscoped.find_by!(sluggable_id: role.id)
    row.update_columns(platform_id: nil) # rubocop:disable Rails/SkipsModelValidations
    FriendlyId::Slug.unscoped.create!(sluggable: role, slug: row.slug, locale: row.locale, platform_id: host.id)

    expect { silently { migration.up } }.not_to raise_error
    expect(row.reload.platform_id).to be_nil
  end

  it 'is idempotent' do
    silently { migration.up }
    expect { silently { migration.up } }.not_to(change(BetterTogether::Role, :count))
  end
end
