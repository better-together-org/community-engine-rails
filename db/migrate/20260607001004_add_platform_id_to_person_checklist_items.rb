# frozen_string_literal: true

# Phase 6 — Platform isolation for join tables.
# PersonChecklistItem allows cross-platform queries without this column.
class AddPlatformIdToPersonChecklistItems < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_person_checklist_items, :platform_id)

    add_reference :better_together_person_checklist_items, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
