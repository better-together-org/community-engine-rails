# frozen_string_literal: true

# Idempotent repair for 20260606001006_add_platform_id_to_content_blocks.
# That migration's partial unique index excluded NULL platform_id but not
# blank identifier, even though Identifier#validate_identifier_uniqueness
# (the app-layer validator the index's own comment cites as covering the
# gap) explicitly skips blank identifiers too. Any host with more than one
# blank-identifier content block hits PG::UniqueViolation the moment a
# later migration backfills platform_id uniformly for both.
#
# Safe to run whether or not the original migration already created the
# old (stricter) index on this host: drops it if present under the old
# definition, then (re)creates it with the corrected predicate. `down` is a
# no-op -- we do not restore the stricter, buggy predicate.
class RepairContentBlocksIdentifierPlatformIndex < ActiveRecord::Migration[7.2]
  INDEX_NAME = 'idx_bt_content_blocks_on_identifier_platform_id'

  def up
    return unless table_exists?(:better_together_content_blocks)
    return unless index_name_exists?(:better_together_content_blocks, INDEX_NAME) ||
                  column_exists?(:better_together_content_blocks, :platform_id)

    remove_index :better_together_content_blocks, name: INDEX_NAME, if_exists: true

    add_index :better_together_content_blocks, %i[identifier platform_id], unique: true,
                                                                           name: INDEX_NAME,
                                                                           where: "platform_id IS NOT NULL AND identifier != ''",
                                                                           if_not_exists: true
  end

  def down; end
end
