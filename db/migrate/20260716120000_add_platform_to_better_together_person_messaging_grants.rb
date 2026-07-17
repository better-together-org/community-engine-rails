# frozen_string_literal: true

# Fixes a cross-platform messaging-permission leak: grants had no platform_id at all,
# so a grant created in one platform's context silently authorized messaging on any
# other platform where the same two people also exist.
class AddPlatformToBetterTogetherPersonMessagingGrants < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:better_together_person_messaging_grants, :platform_id)
      add_reference :better_together_person_messaging_grants, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms }, index: false
    end

    if index_name_exists?(:better_together_person_messaging_grants, 'idx_bt_messaging_grants_grantor_grantee')
      remove_index :better_together_person_messaging_grants, name: 'idx_bt_messaging_grants_grantor_grantee'
    end

    # Pre-existing rows predate platform scoping and were implicitly cross-platform
    # already, so the host platform is the only safe retroactive default.
    host_platform_id = execute(
      'SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1'
    ).first&.fetch('id')

    if host_platform_id
      execute <<~SQL
        UPDATE better_together_person_messaging_grants
        SET platform_id = #{quote(host_platform_id)}
        WHERE platform_id IS NULL
      SQL
    end

    change_column_null :better_together_person_messaging_grants, :platform_id, false

    unless index_name_exists?(:better_together_person_messaging_grants,
                              'idx_bt_messaging_grants_grantor_grantee_platform')
      add_index :better_together_person_messaging_grants,
                %i[grantor_id grantee_id platform_id],
                unique: true,
                name: 'idx_bt_messaging_grants_grantor_grantee_platform'
    end
  end

  def down
    # Relaxes constraints back to the pre-migration shape without dropping the
    # platform_id column/reference itself, so this stays safe to call from specs
    # that need to recreate pre-backfill state (avoids ActiveRecord column-cache
    # invalidation from dropping and re-adding a column mid-process).
    if index_name_exists?(:better_together_person_messaging_grants,
                          'idx_bt_messaging_grants_grantor_grantee_platform')
      remove_index :better_together_person_messaging_grants,
                   name: 'idx_bt_messaging_grants_grantor_grantee_platform'
    end

    if column_exists?(:better_together_person_messaging_grants, :platform_id)
      change_column_null :better_together_person_messaging_grants, :platform_id, true
    end

    return if index_name_exists?(:better_together_person_messaging_grants, 'idx_bt_messaging_grants_grantor_grantee')

    add_index :better_together_person_messaging_grants,
              %i[grantor_id grantee_id],
              unique: true,
              name: 'idx_bt_messaging_grants_grantor_grantee'
  end
end
