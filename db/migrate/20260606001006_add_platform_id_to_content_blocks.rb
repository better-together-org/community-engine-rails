# frozen_string_literal: true

# Phase 5 — Content::Block isolation.
# Covers all 25 STI subclasses (single table inheritance on better_together_content_blocks).
# Removes the old global unique index on identifier and replaces it with a
# composite [identifier, platform_id] unique index, matching the same pattern
# applied to pages/navigation_areas/navigation_items/agreements/categories/
# checklists/uploads/wizards/calls_for_interest — this table was the one
# exception left enforcing no DB-level uniqueness at all after the old index
# was dropped, relying solely on the app-layer Identifier validator.
# Nullable; backfill assigns host platform to pre-existing records.
class AddPlatformIdToContentBlocks < ActiveRecord::Migration[7.2]
  def up
    add_reference :better_together_content_blocks, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true

    remove_index :better_together_content_blocks, :identifier, if_exists: true

    # NOTE: the partial predicate excludes NULL platform_id (pre-backfill legacy
    # rows) and blank identifier -- both gaps are intentional and covered by
    # Identifier#validate_identifier_uniqueness, which itself does
    # `return if identifier.blank?` and never enforces blank-identifier
    # uniqueness at the app layer either. Without excluding blank identifier
    # here, a host with more than one blank-identifier content block (a
    # legitimate, common state for e.g. Content::RichText/Css/Hero blocks
    # accessed via their parent association rather than by identifier) hits a
    # PG::UniqueViolation the moment a later migration backfills platform_id
    # for both onto the same value.
    add_index :better_together_content_blocks, %i[identifier platform_id], unique: true,
                                                                           name: 'idx_bt_content_blocks_on_identifier_platform_id',
                                                                           where: "platform_id IS NOT NULL AND identifier != ''"
  end

  def down
    remove_index :better_together_content_blocks, name: 'idx_bt_content_blocks_on_identifier_platform_id', if_exists: true
    add_index :better_together_content_blocks, :identifier, unique: true, if_not_exists: true
    remove_reference :better_together_content_blocks, :platform, index: true, foreign_key: true
  end
end
