# frozen_string_literal: true

# Phase 5 — Content::Block isolation.
# Covers all 25 STI subclasses (single table inheritance on better_together_content_blocks).
# Removes the old global unique index on identifier — platform-scoped uniqueness is now
# enforced at the application layer via the Identifier concern's validate_identifier_uniqueness.
# Nullable; backfill assigns host platform to pre-existing records.
class AddPlatformIdToContentBlocks < ActiveRecord::Migration[7.2]
  def up
    add_reference :better_together_content_blocks, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true

    # Remove the old global unique index; uniqueness is now scoped to platform_id
    # and enforced by the app-layer validator (no replacement DB-level index needed).
    remove_index :better_together_content_blocks, :identifier, if_exists: true
  end

  def down
    add_index :better_together_content_blocks, :identifier, unique: true, if_not_exists: true
    remove_reference :better_together_content_blocks, :platform, index: true, foreign_key: true
  end
end
