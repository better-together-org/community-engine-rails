# frozen_string_literal: true

# Migration to add children_count column and backfill existing counts for checklist items.
class AddChildrenCountToChecklistItems < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :better_together_checklist_items, :children_count, :integer, default: 0, null: false
    add_index :better_together_checklist_items, :children_count

    reversible do |dir|
      dir.up { backfill_children_count }
    end
  end

  private

  def backfill_children_count # rubocop:disable Metrics/MethodLength
    execute(<<-SQL.squish)
      UPDATE better_together_checklist_items parent
      SET children_count = sub.count
      FROM (
        SELECT parent_id, COUNT(*) as count
        FROM better_together_checklist_items
        WHERE parent_id IS NOT NULL
        GROUP BY parent_id
      ) AS sub
      WHERE parent.id = sub.parent_id
    SQL
  end
end
