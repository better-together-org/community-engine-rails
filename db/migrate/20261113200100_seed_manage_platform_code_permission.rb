# frozen_string_literal: true

# Adds the manage_platform_code permission and the platform_code_manager role. The permission is held
# by no existing role: it is granted explicitly, per platform, by assigning the role.
class SeedManagePlatformCodePermission < ActiveRecord::Migration[7.2]
  def up
    # Earlier migrations in a from-zero run loaded these models before platform_id was added.
    [BetterTogether::ResourcePermission, BetterTogether::Role, BetterTogether::RoleResourcePermission].each(&:reset_column_information)

    permission = BetterTogether::ResourcePermission.find_or_initialize_by(identifier: 'manage_platform_code')
    permission.assign_attributes(action: 'manage', target: 'platform_code', resource_type: 'BetterTogether::Platform',
                                 protected: true)
    permission.position = free_position(permission, 28)
    permission.save!(validate: false)

    role = BetterTogether::Role.find_or_initialize_by(identifier: 'platform_code_manager')
    role.assign_attributes(protected: true, resource_type: 'BetterTogether::Platform',
                           name: 'Platform Code Manager',
                           description: 'May add scripts, styles and meta tags to the platform head and body.')
    role.position = free_position(role, 10)
    role.save!(validate: false)
    role.assign_resource_permissions(%w[read_platform manage_platform_code], sync: true)
  end

  # Keeps an existing record's position. A new one takes the preferred slot, or the next free one when the host
  # app already uses it for a role or permission of its own (the position index is unique per resource type).
  def free_position(record, preferred)
    return record.position unless record.new_record?

    taken = record.class.where(resource_type: record.resource_type).pluck(:position).compact
    taken.include?(preferred) ? taken.max + 1 : preferred
  end

  def down
    role = BetterTogether::Role.find_by(identifier: 'platform_code_manager')
    role&.role_resource_permissions&.delete_all
    role&.destroy
    BetterTogether::ResourcePermission.find_by(identifier: 'manage_platform_code')&.destroy
  end
end
