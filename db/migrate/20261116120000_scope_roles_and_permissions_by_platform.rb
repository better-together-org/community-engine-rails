# frozen_string_literal: true

# Roles, resource permissions and their assignments belong to one platform each. Identifiers and
# positions are unique per platform instead of globally, rows that had no platform go to the host
# platform, every other local platform receives its own copy of the set, and memberships (and the
# other role holders) are repointed to the copy for their own platform.
class ScopeRolesAndPermissionsByPlatform < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  OLD_INDEXES = {
    better_together_roles: { identifier: 'index_better_together_roles_on_identifier',
                             position: 'index_roles_on_resource_type_and_position' },
    better_together_resource_permissions: { identifier: 'index_better_together_resource_permissions_on_identifier',
                                            position: 'index_resource_permissions_on_resource_type_and_position' }
  }.freeze
  SLUG_OWNERS = {
    'BetterTogether::Role' => :better_together_roles,
    'BetterTogether::ResourcePermission' => :better_together_resource_permissions
  }.freeze
  NEW_IDENTIFIER = 'idx_bt_%<table>s_on_platform_identifier'
  NEW_POSITION = 'idx_bt_%<table>s_on_platform_resource_type_position'

  # table => SQL expression for the platform that owns the role holder
  ROLE_HOLDERS = {
    better_together_person_platform_memberships: 't.joinable_id',
    better_together_person_community_memberships: '(SELECT c.platform_id FROM better_together_communities c WHERE c.id = t.joinable_id)',
    better_together_invitations: 't.platform_id',
    better_together_platform_trusted_domains: 't.platform_id'
  }.freeze

  def up
    return unless table_exists?(:better_together_roles) && table_exists?(:better_together_resource_permissions)

    assign_unowned_rows_to_host
    backfill_slug_platforms
    swap_indexes_to_platform_scope
    copy_sets_to_other_platforms
  end

  def down
    return unless table_exists?(:better_together_roles)

    repoint_holders_to_host_roles
    execute <<~SQL.squish
      DELETE FROM better_together_role_resource_permissions WHERE platform_id IS DISTINCT FROM #{host_id_sql}
    SQL
    %w[better_together_roles better_together_resource_permissions].each do |table|
      execute "DELETE FROM #{table} WHERE platform_id IS DISTINCT FROM #{host_id_sql}"
    end
    restore_global_indexes
  end

  private

  def host_id_sql
    '(SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1)'
  end

  def assign_unowned_rows_to_host
    %w[better_together_roles better_together_resource_permissions better_together_role_resource_permissions].each do |table|
      execute "UPDATE #{table} SET platform_id = #{host_id_sql} WHERE platform_id IS NULL"
    end
  end

  # The slug migration ran before roles and permissions had a platform, so their history rows were skipped.
  # A row is left alone when the platform already holds the same slug, which the unique index would reject.
  def backfill_slug_platforms
    return unless table_exists?(:friendly_id_slugs) && column_exists?(:friendly_id_slugs, :platform_id)

    SLUG_OWNERS.each do |type, table|
      execute <<~SQL.squish
        UPDATE friendly_id_slugs s SET platform_id = t.platform_id
        FROM #{table} t
        WHERE s.sluggable_type = #{quote(type)} AND s.sluggable_id = t.id
          AND s.platform_id IS NULL AND t.platform_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM friendly_id_slugs o
            WHERE o.platform_id = t.platform_id AND o.sluggable_type = s.sluggable_type
              AND o.slug = s.slug AND o.locale = s.locale AND o.id <> s.id
          )
      SQL
    end
  end

  def swap_indexes_to_platform_scope
    OLD_INDEXES.each do |table, names|
      remove_index table, name: names[:identifier] if index_name_exists?(table, names[:identifier])
      remove_index table, name: names[:position] if index_name_exists?(table, names[:position])
      identifier_index = new_identifier_index(table)
      position_index = new_position_index(table)
      add_index table, %i[platform_id identifier], unique: true, name: identifier_index unless index_name_exists?(table, identifier_index)
      unless index_name_exists?(table, position_index)
        add_index table, %i[platform_id resource_type position], unique: true, name: position_index
      end
    end
  end

  def restore_global_indexes
    OLD_INDEXES.each do |table, names|
      [new_identifier_index(table), new_position_index(table)].each do |name|
        remove_index table, name: name if index_name_exists?(table, name)
      end
      add_index table, :identifier, unique: true, name: names[:identifier] unless index_name_exists?(table, names[:identifier])
      add_index table, %i[resource_type position], unique: true, name: names[:position] unless index_name_exists?(table, names[:position])
    end
  end

  def new_identifier_index(table)
    format(NEW_IDENTIFIER, table: table.to_s.delete_prefix('better_together_'))
  end

  def new_position_index(table)
    format(NEW_POSITION, table: table.to_s.delete_prefix('better_together_'))
  end

  # Every local, non-host platform without its own roles gets a copy of the host's set.
  def copy_sets_to_other_platforms
    local = column_exists?(:better_together_platforms, :locality) ? "p.locality = 'local'" : 'p.external = FALSE'
    targets = select_values(<<~SQL.squish)
      SELECT p.id FROM better_together_platforms p
      WHERE p.host = FALSE AND #{local}
        AND NOT EXISTS (SELECT 1 FROM better_together_roles r WHERE r.platform_id = p.id)
    SQL
    targets.each { |platform_id| copy_set_to(connection.quote(platform_id)) }
  end

  def copy_set_to(platform) # rubocop:disable Metrics/MethodLength
    execute 'CREATE TEMP TABLE bt_role_map (old_id uuid, new_id uuid) ON COMMIT DROP'
    execute 'CREATE TEMP TABLE bt_perm_map (old_id uuid, new_id uuid) ON COMMIT DROP'
    execute "INSERT INTO bt_role_map SELECT id, gen_random_uuid() FROM better_together_roles WHERE platform_id = #{host_id_sql}"
    execute "INSERT INTO bt_perm_map SELECT id, gen_random_uuid() FROM better_together_resource_permissions WHERE platform_id = #{host_id_sql}"

    copy_rows('better_together_roles', 'bt_role_map', platform, %w[identifier protected position resource_type type])
    copy_rows('better_together_resource_permissions', 'bt_perm_map', platform,
              %w[identifier protected position resource_type action target])
    execute <<~SQL.squish
      INSERT INTO better_together_role_resource_permissions (id, role_id, resource_permission_id, platform_id, created_at, updated_at, lock_version)
      SELECT gen_random_uuid(), rm.new_id, pm.new_id, #{platform}, NOW(), NOW(), 0
      FROM better_together_role_resource_permissions j
      JOIN bt_role_map rm ON rm.old_id = j.role_id
      JOIN bt_perm_map pm ON pm.old_id = j.resource_permission_id
    SQL
    copy_translations('BetterTogether::Role', 'bt_role_map', platform)
    copy_translations('BetterTogether::ResourcePermission', 'bt_perm_map', platform)
    repoint_holders(platform)
    execute 'DROP TABLE bt_role_map'
    execute 'DROP TABLE bt_perm_map'
  end

  def copy_rows(table, map, platform, columns)
    list = columns.join(', ')
    prefixed = columns.map { |c| "s.#{c}" }.join(', ')
    execute <<~SQL.squish
      INSERT INTO #{table} (id, #{list}, platform_id, created_at, updated_at, lock_version)
      SELECT m.new_id, #{prefixed}, #{platform}, NOW(), NOW(), 0
      FROM #{table} s JOIN #{map} m ON m.old_id = s.id
    SQL
  end

  def copy_translations(type, map, platform)
    %w[mobility_string_translations mobility_text_translations].each do |table|
      next unless table_exists?(table)

      execute <<~SQL.squish
        INSERT INTO #{table} (locale, key, value, translatable_type, translatable_id, created_at, updated_at)
        SELECT s.locale, s.key, s.value, s.translatable_type, m.new_id, NOW(), NOW()
        FROM #{table} s JOIN #{map} m ON m.old_id = s.translatable_id
        WHERE s.translatable_type = #{connection.quote(type)}
      SQL
    end
    return unless table_exists?(:friendly_id_slugs) && column_exists?(:friendly_id_slugs, :platform_id)

    execute <<~SQL.squish
      INSERT INTO friendly_id_slugs (slug, sluggable_id, sluggable_type, scope, locale, platform_id, lock_version, created_at, updated_at)
      SELECT DISTINCT ON (s.slug, s.locale, m.new_id)
             s.slug, m.new_id, s.sluggable_type, s.scope, s.locale, #{platform}, 0, NOW(), NOW()
      FROM friendly_id_slugs s JOIN #{map} m ON m.old_id = s.sluggable_id
      WHERE s.sluggable_type = #{connection.quote(type)}
      ORDER BY s.slug, s.locale, m.new_id, s.id DESC
    SQL
  end

  def repoint_holders(platform)
    ROLE_HOLDERS.each do |table, owner_sql|
      next unless table_exists?(table) && column_exists?(table, :role_id)
      next if owner_sql.include?('t.platform_id') && !column_exists?(table, :platform_id)

      execute <<~SQL.squish
        UPDATE #{table} t SET role_id = rm.new_id
        FROM bt_role_map rm
        WHERE t.role_id = rm.old_id AND #{owner_sql} = #{platform}
      SQL
    end
  end

  def repoint_holders_to_host_roles
    ROLE_HOLDERS.each_key do |table|
      next unless table_exists?(table) && column_exists?(table, :role_id)

      execute <<~SQL.squish
        UPDATE #{table} t SET role_id = host_role.id
        FROM better_together_roles copy_role
        JOIN better_together_roles host_role
          ON host_role.identifier = copy_role.identifier AND host_role.platform_id = #{host_id_sql}
        WHERE t.role_id = copy_role.id AND copy_role.platform_id IS DISTINCT FROM #{host_id_sql}
      SQL
    end
  end
end
