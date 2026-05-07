# frozen_string_literal: true

class AddSyncTrackingToBillingRecords < ActiveRecord::Migration[7.2]
  def change
    add_subscription_sync_columns
    add_event_attempt_columns
  end

  private

  def add_subscription_sync_columns
    add_column_unless_exists :better_together_billing_subscriptions, :last_synced_at, :datetime
    add_column_unless_exists :better_together_billing_subscriptions, :sync_source, :string
    add_column_unless_exists :better_together_billing_subscriptions, :latest_processor_event_id, :string
    add_column_unless_exists :better_together_billing_subscriptions, :latest_checkout_session_id, :string

    add_index_unless_exists(
      :better_together_billing_subscriptions,
      :last_synced_at,
      name: 'idx_bt_billing_subscriptions_last_synced_at'
    )
  end

  def add_event_attempt_columns
    add_column_unless_exists :better_together_billing_events, :first_received_at, :datetime
    add_column_unless_exists :better_together_billing_events, :last_attempted_at, :datetime
    add_column_unless_exists :better_together_billing_events, :attempt_count, :integer, default: 0, null: false

    add_index_unless_exists(
      :better_together_billing_events,
      :last_attempted_at,
      name: 'idx_bt_billing_events_last_attempted_at'
    )
  end

  def add_column_unless_exists(table_name, column_name, type, **)
    return if column_exists?(table_name, column_name)

    add_column table_name, column_name, type, **
  end

  def add_index_unless_exists(table_name, columns, name:)
    return if index_exists?(table_name, columns, name:)

    add_index table_name, columns, name:
  end
end
