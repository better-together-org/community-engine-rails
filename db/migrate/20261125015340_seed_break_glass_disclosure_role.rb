# frozen_string_literal: true

# Adds the sealed manage_break_glass_disclosure permission and the platform_disclosure_officer role to every
# platform that has roles. The role is assigned to no one and no other role gains the permission, so nobody
# can request a break-glass grant until a person is deliberately given the role. Idempotent.
class SeedBreakGlassDisclosureRole < ActiveRecord::Migration[7.2]
  PERMISSION = 'manage_break_glass_disclosure'
  ROLE = 'platform_disclosure_officer'
  RESOURCE_TYPE = 'BetterTogether::Platform'

  def up
    return unless tables_ready?

    models.each(&:reset_column_information)
    BetterTogether::Role.where.not(platform_id: nil).distinct.pluck(:platform_id).each { |id| seed_platform(id) }
  end

  def down
    return unless tables_ready?

    role_ids = BetterTogether::Role.where(identifier: ROLE).pluck(:id)
    permission_ids = BetterTogether::ResourcePermission.where(identifier: PERMISSION).pluck(:id)
    BetterTogether::PersonPlatformMembership.where(role_id: role_ids).delete_all
    BetterTogether::RoleResourcePermission.where(role_id: role_ids).delete_all
    BetterTogether::RoleResourcePermission.where(resource_permission_id: permission_ids).delete_all
    # Protected rows refuse #destroy, so remove them directly.
    BetterTogether::Role.where(id: role_ids).delete_all
    BetterTogether::ResourcePermission.where(id: permission_ids).delete_all
  end

  private

  def models
    [BetterTogether::ResourcePermission, BetterTogether::Role, BetterTogether::RoleResourcePermission]
  end

  def tables_ready?
    %i[better_together_resource_permissions better_together_roles better_together_role_resource_permissions]
      .all? { |table| table_exists?(table) && column_exists?(table, :platform_id) }
  end

  def seed_platform(platform_id)
    permission = find_or_create(BetterTogether::ResourcePermission, platform_id, PERMISSION, 30) do |record|
      record.assign_attributes(action: 'manage', target: 'break_glass_disclosure')
    end
    role = find_or_create(BetterTogether::Role, platform_id, ROLE, 12) do |record|
      record.assign_attributes(name: 'Platform Disclosure Officer',
                               description: 'Sealed role. May request a time-limited, audited break-glass grant ' \
                                            'to read one private record. Assigned to no one by default.')
    end
    [PERMISSION, 'read_platform'].each { |identifier| join(platform_id, role, identifier, permission) }
  end

  def find_or_create(klass, platform_id, identifier, preferred_position)
    record = klass.find_or_initialize_by(identifier:, platform_id:)
    return record if record.persisted?

    record.resource_type = RESOURCE_TYPE
    record.protected = true
    record.position = free_position(klass, platform_id, preferred_position)
    yield record
    record.save!(validate: false)
    record
  end

  def free_position(klass, platform_id, preferred)
    scope = klass.where(platform_id:, resource_type: RESOURCE_TYPE)
    scope.exists?(position: preferred) ? scope.maximum(:position).to_i + 1 : preferred
  end

  def join(platform_id, role, identifier, known_permission)
    permission = identifier == PERMISSION ? known_permission : find_permission(platform_id, identifier)
    return unless permission
    return if BetterTogether::RoleResourcePermission.exists?(role_id: role.id, resource_permission_id: permission.id)

    BetterTogether::RoleResourcePermission.create!(role_id: role.id, resource_permission_id: permission.id,
                                                   platform_id:)
  end

  def find_permission(platform_id, identifier)
    BetterTogether::ResourcePermission.find_by(identifier:, platform_id:)
  end
end
