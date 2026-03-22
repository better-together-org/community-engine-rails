# frozen_string_literal: true

# PostgreSQL does not consider NULL values equal in unique indexes, so the composite
# unique index on person_links (platform_connection_id, source_person_id, target_person_id)
# and person_access_grants (person_link_id, grantor_person_id, grantee_person_id) both
# fail to prevent duplicate rows when the nullable FK column is NULL (i.e. remote targets).
#
# Fix: replace each three-column unique index with two partial unique indexes:
#   1. A unique index covering the local-target case (FK IS NOT NULL)
#   2. A unique index covering the remote-target case on the identifier column (FK IS NULL)
class FixNullUniqueIndexesForRemoteTargets < ActiveRecord::Migration[7.2]
  def up
    # --- person_links ---
    remove_index :better_together_person_links,
                 name: 'index_bt_person_links_on_connection_and_people'

    # Local target: standard equality check works because target_person_id IS NOT NULL
    add_index :better_together_person_links,
              %i[platform_connection_id source_person_id target_person_id],
              unique: true,
              where: 'target_person_id IS NOT NULL',
              name: 'index_bt_person_links_local_target_unique'

    # Remote target: deduplicate by identifier instead of NULL FK
    add_index :better_together_person_links,
              %i[platform_connection_id source_person_id remote_target_identifier],
              unique: true,
              where: 'target_person_id IS NULL',
              name: 'index_bt_person_links_remote_target_unique'

    # --- person_access_grants ---
    remove_index :better_together_person_access_grants,
                 name: 'index_bt_person_access_grants_on_link_and_people'

    # Local grantee
    add_index :better_together_person_access_grants,
              %i[person_link_id grantor_person_id grantee_person_id],
              unique: true,
              where: 'grantee_person_id IS NOT NULL',
              name: 'index_bt_person_access_grants_local_grantee_unique'

    # Remote grantee
    add_index :better_together_person_access_grants,
              %i[person_link_id grantor_person_id remote_grantee_identifier],
              unique: true,
              where: 'grantee_person_id IS NULL',
              name: 'index_bt_person_access_grants_remote_grantee_unique'
  end

  def down
    remove_index :better_together_person_links, name: 'index_bt_person_links_local_target_unique'
    remove_index :better_together_person_links, name: 'index_bt_person_links_remote_target_unique'
    add_index :better_together_person_links,
              %i[platform_connection_id source_person_id target_person_id],
              unique: true,
              name: 'index_bt_person_links_on_connection_and_people'

    remove_index :better_together_person_access_grants,
                 name: 'index_bt_person_access_grants_local_grantee_unique'
    remove_index :better_together_person_access_grants,
                 name: 'index_bt_person_access_grants_remote_grantee_unique'
    add_index :better_together_person_access_grants,
              %i[person_link_id grantor_person_id grantee_person_id],
              unique: true,
              name: 'index_bt_person_access_grants_on_link_and_people'
  end
end
