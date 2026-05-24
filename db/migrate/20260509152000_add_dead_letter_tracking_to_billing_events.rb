# frozen_string_literal: true

class AddDeadLetterTrackingToBillingEvents < ActiveRecord::Migration[7.1]
  def change
    add_missing_columns
    add_missing_indexes
  end

  private

  def add_missing_columns
    add_column_if_missing :dead_lettered_at, :datetime
    add_column_if_missing :dead_letter_reason, :string
    add_column_if_missing :last_replayed_at, :datetime
    add_column_if_missing :replay_count, :integer, null: false, default: 0
    add_column_if_missing :last_replay_requested_by_type, :string
    add_column_if_missing :last_replay_requested_by_id, :uuid
  end

  def add_missing_indexes
    add_dead_lettered_at_index
    add_last_replay_requested_by_index
  end

  def add_column_if_missing(column_name, type, **)
    return if column_exists?(:better_together_billing_events, column_name)

    add_column :better_together_billing_events, column_name, type, **
  end

  def add_dead_lettered_at_index
    return if index_exists?(:better_together_billing_events, :dead_lettered_at,
                            name: 'idx_bt_billing_events_dead_lettered_at')

    add_index :better_together_billing_events, :dead_lettered_at,
              name: 'idx_bt_billing_events_dead_lettered_at'
  end

  def add_last_replay_requested_by_index
    columns = %i[last_replay_requested_by_type last_replay_requested_by_id]
    index_name = 'idx_bt_billing_events_last_replay_requested_by'
    return if index_exists?(:better_together_billing_events, columns, name: index_name)

    add_index :better_together_billing_events, columns, name: index_name
  end
end
