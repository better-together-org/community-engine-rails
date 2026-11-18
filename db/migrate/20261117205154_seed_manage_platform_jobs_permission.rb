# frozen_string_literal: true

# Adds the manage_platform_jobs permission (background jobs screen and /sidekiq) to every platform that
# has roles, and grants it to each role on that platform holding manage_platform or
# manage_platform_settings, so nobody who could open Sidekiq before loses it. Idempotent.
class SeedManagePlatformJobsPermission < ActiveRecord::Migration[7.2]
  IDENTIFIER = 'manage_platform_jobs'
  GRANTED_WITH = %w[manage_platform manage_platform_settings].freeze
  PREFERRED_POSITION = 29

  def up
    return unless tables_ready?

    models.each(&:reset_column_information)
    platform_ids.each { |platform_id| seed_platform(platform_id) }
  end

  def down
    return unless tables_ready?

    permission_ids = BetterTogether::ResourcePermission.where(identifier: IDENTIFIER).pluck(:id)
    BetterTogether::RoleResourcePermission.where(resource_permission_id: permission_ids).delete_all
    # Protected rows refuse #destroy, so delete them and their slug history directly.
    if table_exists?(:friendly_id_slugs)
      FriendlyId::Slug.where(sluggable_type: 'BetterTogether::ResourcePermission', sluggable_id: permission_ids).delete_all
    end
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

  def platform_ids
    BetterTogether::Role.where.not(platform_id: nil).distinct.pluck(:platform_id)
  end

  def seed_platform(platform_id)
    permission = find_or_create_permission(platform_id)
    role_ids_to_grant(platform_id).each do |role_id|
      next if BetterTogether::RoleResourcePermission.exists?(role_id:, resource_permission_id: permission.id)

      BetterTogether::RoleResourcePermission.create!(role_id:, resource_permission_id: permission.id, platform_id:)
    end
  end

  def find_or_create_permission(platform_id)
    permission = BetterTogether::ResourcePermission.find_or_initialize_by(identifier: IDENTIFIER, platform_id:)
    return permission if permission.persisted?

    permission.assign_attributes(action: 'manage', target: 'platform_jobs', resource_type: 'BetterTogether::Platform',
                                 protected: true, position: free_position(platform_id))
    permission.save!(validate: false)
    permission
  end

  def free_position(platform_id)
    scope = BetterTogether::ResourcePermission.where(platform_id:, resource_type: 'BetterTogether::Platform')
    return PREFERRED_POSITION unless scope.exists?(position: PREFERRED_POSITION)

    scope.maximum(:position).to_i + 1
  end

  def role_ids_to_grant(platform_id)
    source_permissions = BetterTogether::ResourcePermission.where(platform_id:, identifier: GRANTED_WITH).select(:id)
    BetterTogether::RoleResourcePermission.where(platform_id:, resource_permission_id: source_permissions)
                                          .distinct.pluck(:role_id)
  end
end
