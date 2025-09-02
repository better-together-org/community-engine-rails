# frozen_string_literal: true

# Migration to add a counter cache column for number of children on checklist items.
class AddChildrenCountToChecklistItems < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # Only add the column/index if they don't already exist (safe reruns)
    unless column_exists?(:better_together_checklist_items, :children_count)
      add_column :better_together_checklist_items, :children_count, :integer, default: 0, null: false
      add_index :better_together_checklist_items, :children_count
    end

    reversible do |dir|
      dir.up do
        backfill_children_count if column_exists?(:better_together_checklist_items, :parent_id)
      end
    end
  end

  private

  def backfill_children_count # rubocop:disable Metrics/MethodLength
    # Backfill counts without locking the whole table
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
