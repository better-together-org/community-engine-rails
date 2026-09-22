# frozen_string_literal: true

# Replace the bare unique index on better_together_posts.identifier with a
# composite unique index on [identifier, platform_id], matching
# 20260703171020_replace_pages_identifier_unique_index_with_platform_scoped
# (posts.identifier was left with the old global index when pages got this fix,
# an asymmetry flagged but never actioned — same duplicate-identifier-across-
# platforms risk that caused the original friendly-slug production incident,
# just not yet triggered for Posts). Same rationale: allows the same identifier
# to exist on different platforms while maintaining uniqueness within each
# platform, aligned with the platform-scoped validation logic in the Identifier
# concern.
class ReplacePostsIdentifierUniqueIndexWithPlatformScoped < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_posts) && index_exists?(:better_together_posts, :identifier, unique: true)

    remove_index :better_together_posts, :identifier

    # NOTE: The partial predicate (platform_id IS NOT NULL) means two records with
    # the same identifier and a NULL platform_id are NOT caught by this index.
    # The Identifier#validate_identifier_uniqueness model validation covers that gap.
    add_index :better_together_posts, %i[identifier platform_id], unique: true,
                                                                  name: 'idx_bt_posts_on_identifier_platform_id',
                                                                  where: 'platform_id IS NOT NULL'
  end
end
