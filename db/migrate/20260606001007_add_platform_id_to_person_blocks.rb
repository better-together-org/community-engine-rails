# frozen_string_literal: true

# Phase 5 — PersonBlock isolation.
# Blocking is now per-platform: person A can block person B on Platform 1
# without affecting their relationship on Platform 2.
# Drops the old (blocker_id, blocked_id) unique index and replaces it with
# a compound (blocker_id, blocked_id, platform_id) unique index.
class AddPlatformIdToPersonBlocks < ActiveRecord::Migration[7.2]
  def up
    add_reference :better_together_person_blocks, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: false # We add a compound index below instead

    remove_index :better_together_person_blocks, %i[blocker_id blocked_id], if_exists: true

    add_index :better_together_person_blocks, %i[blocker_id blocked_id platform_id], unique: true
  end

  def down
    remove_index :better_together_person_blocks, %i[blocker_id blocked_id platform_id], if_exists: true
    add_index :better_together_person_blocks, %i[blocker_id blocked_id], unique: true
    remove_reference :better_together_person_blocks, :platform, foreign_key: true
  end
end
