# frozen_string_literal: true

# Adds the manage_platform_code permission and the platform_code_manager role. The permission is held
# by no existing role: it is granted explicitly, per platform, by assigning the role.
class SeedManagePlatformCodePermission < ActiveRecord::Migration[7.2]
  def up
    permission = BetterTogether::ResourcePermission.find_or_initialize_by(identifier: 'manage_platform_code')
    permission.assign_attributes(action: 'manage', target: 'platform_code', resource_type: 'BetterTogether::Platform',
                                 protected: true, position: 28)
    permission.save!(validate: false)

    role = BetterTogether::Role.find_or_initialize_by(identifier: 'platform_code_manager')
    role.assign_attributes(protected: true, position: 10, resource_type: 'BetterTogether::Platform',
                           name: 'Platform Code Manager',
                           description: 'May add scripts, styles and meta tags to the platform head and body.')
    role.save!(validate: false)
    role.assign_resource_permissions(%w[read_platform manage_platform_code], sync: true)
  end

  def down
    role = BetterTogether::Role.find_by(identifier: 'platform_code_manager')
    role&.role_resource_permissions&.delete_all
    role&.destroy
    BetterTogether::ResourcePermission.find_by(identifier: 'manage_platform_code')&.destroy
  end
end
