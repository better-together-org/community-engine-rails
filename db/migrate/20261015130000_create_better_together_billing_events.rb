# frozen_string_literal: true

# Processor-neutral billing event log: one row per processor event, kept for audit,
# retry, dead-lettering and replay. Final state; guarded so a re-run is a no-op.
#
# * platform_id NOT NULL: every event belongs to exactly one platform and nothing
#   guesses which (see BetterTogether::Billing::PlatformBound).
# * payload and error_message are `text` because the model encrypts them
#   (BetterTogether::Billing::EncryptedAttributes); ciphertext is not a JSON document,
#   so a jsonb column cannot hold it, and an encrypted column takes no default.
# * The vendor's own event time is kept separately from when we received it, so a stale
#   event can be told apart from a newer one.
# * subject is what the event is about (an order, a Joatu agreement, a platform...): a
#   polymorphic reference limited to types that opted in with Billing::Subjectable.
#   outcome_kind is the processor-neutral meaning of the outcome (payment_failed,
#   refund_issued...) that notifications and reports key off; processor event names
#   never leave the adapter.
# * claimed_at is a short lease taken while a job processes the event, so two jobs for
#   the same event (a duplicate delivery, a replay) never run the processor at once.
class CreateBetterTogetherBillingEvents < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_events

  def up
    return if table_exists?(TABLE)

    create_bt_table :billing_events do |t| # rubocop:disable Metrics/BlockLength
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_events_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.string :billable_owner_type
      t.uuid :billable_owner_id
      t.string :beneficiary_type
      t.uuid :beneficiary_id
      t.string :subject_type
      t.uuid :subject_id
      t.string :outcome_kind
      t.string :processor, null: false
      t.string :event_type, null: false
      t.string :event_id, null: false
      t.text :payload, null: false
      t.string :processing_status, null: false, default: 'pending'
      t.text :error_message
      t.integer :attempt_count, null: false, default: 0
      t.integer :replay_count, null: false, default: 0
      t.string :dead_letter_reason
      t.string :last_replay_requested_by_type
      t.uuid :last_replay_requested_by_id
      t.datetime :first_received_at
      t.datetime :processor_event_created_at
      t.datetime :last_attempted_at
      t.datetime :claimed_at
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

  # Vendor event ids are globally unique, so (processor, event_id) is unique across
  # platforms; the ingest refuses to hand one platform another platform's event.
  def add_indexes
    add_index TABLE, %i[processor event_id], unique: true, name: 'idx_bt_billing_events_processor_event'
    add_index TABLE, %i[billable_owner_type billable_owner_id], name: 'idx_bt_billing_events_owner'
    add_index TABLE, %i[beneficiary_type beneficiary_id], name: 'idx_bt_billing_events_beneficiary'
    add_index TABLE, %i[subject_type subject_id], name: 'idx_bt_billing_events_subject'
    add_index TABLE, :outcome_kind, name: 'idx_bt_billing_events_outcome_kind'
    add_index TABLE, :processing_status, name: 'idx_bt_billing_events_processing_status'
    add_index TABLE, :last_attempted_at, name: 'idx_bt_billing_events_last_attempted_at'
    add_index TABLE, :payload_redacted_at, name: 'idx_bt_billing_events_payload_redacted_at'
    add_index TABLE, :dead_lettered_at, name: 'idx_bt_billing_events_dead_lettered_at'
  end
end
