# frozen_string_literal: true

# Replace bare unique indexes on `identifier` with composite unique indexes on
# `[identifier, platform_id]` for the platform-scoped tables missed by
# 20260606005001_replace_identifier_unique_indexes_for_platform_scoped_tables.
# Same rationale: allows the same identifier to exist on different platforms
# while maintaining uniqueness within each platform, aligned with the
# platform-scoped validation logic in the Identifier concern.
class ReplaceIdentifierUniqueIndexesForRemainingPlatformScopedTables < ActiveRecord::Migration[7.2]
  def change
    # Explicit names required — auto-generated names for long table names
    # exceed PostgreSQL's 63-character index name limit.
    tables_to_migrate = {
      better_together_checklists: 'idx_bt_checklists_on_identifier_platform_id',
      better_together_uploads: 'idx_bt_uploads_on_identifier_platform_id',
      better_together_wizards: 'idx_bt_wizards_on_identifier_platform_id',
      better_together_calls_for_interest: 'idx_bt_calls_for_interest_on_identifier_platform_id'
    }.freeze

    tables_to_migrate.each do |table, index_name|
      next unless table_exists?(table) && index_exists?(table, :identifier, unique: true)

      # Remove the existing unique index on identifier alone
      remove_index table, :identifier

      # Add a new composite unique index on [identifier, platform_id].
      # NOTE: The partial predicate (platform_id IS NOT NULL) means two records with
      # the same identifier and a NULL platform_id are NOT caught by this index.
      # The Identifier#validate_identifier_uniqueness model validation covers that gap.
      add_index table, %i[identifier platform_id], unique: true,
                                                   name: index_name,
                                                   where: "platform_id IS NOT NULL"
    end
  end
end
