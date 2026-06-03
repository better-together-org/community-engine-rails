# frozen_string_literal: true

class SeedPlatformMemberRoleBeforeHostBackfill < ActiveRecord::Migration[7.2]
  class Role < ActiveRecord::Base
    self.table_name = 'better_together_roles'
    self.inheritance_column = :_type_disabled
  end

  class ResourcePermission < ActiveRecord::Base
    self.table_name = 'better_together_resource_permissions'
  end

  class RoleResourcePermission < ActiveRecord::Base
    self.table_name = 'better_together_role_resource_permissions'
  end

  class MobilityStringTranslation < ActiveRecord::Base
    self.table_name = 'mobility_string_translations'
  end

  class MobilityTextTranslation < ActiveRecord::Base
    self.table_name = 'mobility_text_translations'
  end

  class FriendlyIdSlug < ActiveRecord::Base
    self.table_name = 'friendly_id_slugs'
  end

  def up
    role = Role.find_or_initialize_by(identifier: 'platform_member')
    role.assign_attributes(
      protected: true,
      resource_type: 'BetterTogether::Platform',
      type: 'BetterTogether::Role'
    )
    role.position ||= next_position_for(Role, 'BetterTogether::Platform')
    role.save! if role.changed?
    upsert_slug!(role, 'BetterTogether::Role')

    upsert_role_translation!(
      MobilityStringTranslation,
      role.id,
      'name',
      'Platform Member'
    )
    upsert_role_translation!(
      MobilityTextTranslation,
      role.id,
      'description',
      'Basic platform role for signed-in members who can access platform information without platform management authority.'
    )

    permission = ResourcePermission.find_or_initialize_by(identifier: 'read_platform')
    permission.assign_attributes(
      action: 'read',
      target: 'platform',
      resource_type: 'BetterTogether::Platform',
      protected: true,
      position: 1
    )
    permission.save! if permission.changed?
    upsert_slug!(permission, 'BetterTogether::ResourcePermission')

    RoleResourcePermission.find_or_create_by!(
      role_id: role.id,
      resource_permission_id: permission.id
    )

    activate_existing_host_platform_managers!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def next_position_for(model_class, resource_type)
    max_position = model_class.where(resource_type: resource_type).maximum(:position)
    max_position ? max_position + 1 : 0
  end

  def upsert_role_translation!(translation_class, role_id, key, value)
    translation = translation_class.find_or_initialize_by(
      locale: I18n.default_locale.to_s,
      key:,
      translatable_type: 'BetterTogether::Role',
      translatable_id: role_id
    )
    translation.value = value
    translation.save! if translation.changed?
  end

  def upsert_slug!(record, sluggable_type)
    slug = record.identifier.to_s.parameterize
    upsert_mobility_slug!(sluggable_type, record.id, slug)

    friendly_slug = FriendlyIdSlug.find_or_initialize_by(
      sluggable_type:,
      sluggable_id: record.id,
      locale: I18n.default_locale.to_s
    )
    friendly_slug.slug = slug
    friendly_slug.scope = nil
    friendly_slug.save! if friendly_slug.changed?
  end

  def upsert_mobility_slug!(translatable_type, translatable_id, slug)
    translation = MobilityStringTranslation.find_or_initialize_by(
      locale: I18n.default_locale.to_s,
      key: 'slug',
      translatable_type:,
      translatable_id:
    )
    translation.value = slug
    translation.save! if translation.changed?
  end

  def activate_existing_host_platform_managers!
    execute <<~SQL.squish
      UPDATE better_together_person_platform_memberships memberships
      SET    status = 'active',
             updated_at = NOW()
      FROM   better_together_roles roles,
             better_together_platforms platforms
      WHERE  memberships.role_id = roles.id
        AND  memberships.joinable_id = platforms.id
        AND  platforms.host = TRUE
        AND  memberships.status = 'pending'
        AND  roles.identifier IN ('platform_steward', 'platform_manager')
    SQL
  end
end
