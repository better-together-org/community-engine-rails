# frozen_string_literal: true

# Processor-neutral billing event log: one row per processor event, kept for audit,
# retry, dead-lettering and replay. Final state; guarded so a re-run is a no-op.
class CreateBetterTogetherBillingEvents < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_events

  def up
    return if table_exists?(TABLE)

    create_bt_table :billing_events do |t|
      t.string :billable_owner_type
      t.uuid :billable_owner_id
      t.string :beneficiary_type
      t.uuid :beneficiary_id
      t.string :processor, null: false
      t.string :event_type, null: false
      t.string :event_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :processing_status, null: false, default: 'pending'
      t.text :error_message
      t.integer :attempt_count, null: false, default: 0
      t.integer :replay_count, null: false, default: 0
      t.string :dead_letter_reason
      t.string :last_replay_requested_by_type
      t.uuid :last_replay_requested_by_id
      t.datetime :first_received_at
      t.datetime :last_attempted_at
      t.datetime :processed_at
      t.datetime :payload_redacted_at
      t.datetime :dead_lettered_at
      t.datetime :last_replayed_at
    end

    add_indexes
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end

  private

  def add_indexes
    add_index TABLE, %i[processor event_id], unique: true, name: 'idx_bt_billing_events_processor_event'
    add_index TABLE, %i[billable_owner_type billable_owner_id], name: 'idx_bt_billing_events_owner'
    add_index TABLE, %i[beneficiary_type beneficiary_id], name: 'idx_bt_billing_events_beneficiary'
    add_index TABLE, :processing_status, name: 'idx_bt_billing_events_processing_status'
    add_index TABLE, :last_attempted_at, name: 'idx_bt_billing_events_last_attempted_at'
    add_index TABLE, :payload_redacted_at, name: 'idx_bt_billing_events_payload_redacted_at'
    add_index TABLE, :dead_lettered_at, name: 'idx_bt_billing_events_dead_lettered_at'
  end
end
