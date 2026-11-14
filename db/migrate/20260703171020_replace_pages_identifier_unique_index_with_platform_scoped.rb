# frozen_string_literal: true

# Replace the bare unique index on better_together_pages.identifier with a
# composite unique index on [identifier, platform_id], matching
# 20260606005001_replace_identifier_unique_indexes_for_platform_scoped_tables
# and 20260702200000_replace_identifier_unique_indexes_for_remaining_platform_scoped_tables.
# Same rationale: allows the same identifier to exist on different platforms
# while maintaining uniqueness within each platform, aligned with the
# platform-scoped validation logic in the Identifier concern.
class ReplacePagesIdentifierUniqueIndexWithPlatformScoped < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_pages) && index_exists?(:better_together_pages, :identifier, unique: true)

    remove_index :better_together_pages, :identifier

    # NOTE: The partial predicate (platform_id IS NOT NULL) means two records with
    # the same identifier and a NULL platform_id are NOT caught by this index.
    # The Identifier#validate_identifier_uniqueness model validation covers that gap.
    add_index :better_together_pages, %i[identifier platform_id], unique: true,
                                                                  name: 'idx_bt_pages_on_identifier_platform_id',
                                                                  where: 'platform_id IS NOT NULL'
  end
end
