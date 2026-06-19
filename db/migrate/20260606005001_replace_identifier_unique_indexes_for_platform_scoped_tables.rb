# frozen_string_literal: true

# Replace bare unique indexes on `identifier` with composite unique indexes on
# `[identifier, platform_id]` for all platform-scoped tables. This allows the
# same identifier to exist on different platforms while maintaining uniqueness
# within each platform, aligned with the platform-scoped validation logic in
# the Identifier concern.
class ReplaceIdentifierUniqueIndexesForPlatformScopedTables < ActiveRecord::Migration[7.2]
  def change
    # Platform-scoped tables that have unique indexes on identifier.
    # Categories has a composite index on [identifier, type], so requires special handling.
    # Explicit names required — auto-generated names for long table names exceed
    # PostgreSQL's 63-character index name limit.
    tables_to_migrate = {
      better_together_navigation_areas: 'idx_bt_nav_areas_on_identifier_platform_id',
      better_together_navigation_items: 'idx_bt_nav_items_on_identifier_platform_id',
      better_together_agreements: 'idx_bt_agreements_on_identifier_platform_id',
      better_together_categories: 'idx_bt_categories_on_identifier_platform_id'
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

    # Categories has a composite index on [identifier, type] — replace it with
    # [identifier, type, platform_id] to maintain both type and platform scoping.
    if table_exists?(:better_together_categories) &&
       index_exists?(:better_together_categories, %i[identifier type], unique: true)
      remove_index :better_together_categories, %i[identifier type]
      # Same NULL gap applies: records with platform_id IS NULL rely on model validation.
      add_index :better_together_categories, %i[identifier type platform_id],
                unique: true,
                name: 'idx_bt_categories_on_identifier_type_platform_id',
                where: "platform_id IS NOT NULL"
    end
  end
end
