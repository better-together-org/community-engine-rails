# frozen_string_literal: true

# Adds an explicit lifecycle status (draft/confirmed/cancelled) to events.
# Previously "draft" was derived from starts_at being NULL; status is stored
# state, orthogonal to scheduling. Existing unscheduled events are backfilled
# as drafts; everything else is confirmed.
class AddStatusToBetterTogetherEvents < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:better_together_events, :status)
      add_column :better_together_events, :status, :string, null: false, default: 'confirmed'
      execute <<~SQL.squish
        UPDATE better_together_events SET status = 'draft' WHERE starts_at IS NULL
      SQL
    end

    return if index_name_exists?(:better_together_events, 'by_better_together_events_status')

    add_index :better_together_events, :status, name: 'by_better_together_events_status'
  end

  def down
    if index_name_exists?(:better_together_events, 'by_better_together_events_status')
      remove_index :better_together_events, name: 'by_better_together_events_status'
    end

    remove_column :better_together_events, :status if column_exists?(:better_together_events, :status)
  end
end
