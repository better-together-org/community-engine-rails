# frozen_string_literal: true

class CreateBetterTogetherBillingTables < ActiveRecord::Migration[7.2]
  def change
    create_billing_plans
    create_billing_subscriptions
    create_billing_events
  end

  private

  def create_billing_plans
    return if table_exists?(:better_together_billing_plans)

    create_bt_table :billing_plans do |t|
      t.string :identifier, null: false
      t.string :name, null: false
      t.text :description
      t.string :billing_interval, null: false, default: 'month'
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: 'CAD'
      t.boolean :active, null: false, default: true
      t.string :stripe_price_id, null: false
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_billing_plans, :identifier,
              unique: true,
              name: 'idx_bt_billing_plans_identifier'
    add_index :better_together_billing_plans, :active,
              name: 'idx_bt_billing_plans_active'
    add_index :better_together_billing_plans, :stripe_price_id,
              unique: true,
              name: 'idx_bt_billing_plans_stripe_price_id'
  end

  # Thin extension record that hangs CE-specific data off pay's subscription.
  # Status, period, and cancellation state live on pay_subscriptions; this
  # record stores only CE billing-plan linkage and operational metadata.
  def create_billing_subscriptions
    return if table_exists?(:better_together_billing_subscriptions)

    create_bt_table :billing_subscriptions do |t|
      t.references :pay_subscription,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :pay_subscriptions, on_delete: :cascade },
                   index: { unique: true, name: 'idx_bt_billing_subscriptions_pay_subscription' }
      t.references :billing_plan,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_billing_plans, on_delete: :restrict },
                   index: { name: 'idx_bt_billing_subscriptions_plan' }
      t.string :sync_source
      t.string :latest_checkout_session_id
      t.string :latest_processor_event_id
      t.datetime :last_synced_at
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_billing_subscriptions, :last_synced_at,
              name: 'idx_bt_billing_subscriptions_last_synced_at'
  end

  def create_billing_events
    return if table_exists?(:better_together_billing_events)

    create_bt_table :billing_events do |t|
      t.references :billing_subscription,
                   type: :uuid,
                   null: true,
                   foreign_key: { to_table: :better_together_billing_subscriptions, on_delete: :nullify },
                   index: { name: 'idx_bt_billing_events_subscription' }
      t.string :billable_owner_type
      t.uuid :billable_owner_id
      t.string :processor, null: false, default: 'stripe'
      t.string :event_type, null: false
      t.string :event_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at
      t.string :processing_status, null: false, default: 'pending'
      t.text :error_message
      t.datetime :first_received_at
      t.datetime :last_attempted_at
      t.integer :attempt_count, null: false, default: 0
      t.datetime :payload_redacted_at
      t.datetime :dead_lettered_at
      t.string :dead_letter_reason
      t.datetime :last_replayed_at
      t.integer :replay_count, null: false, default: 0
      t.string :last_replay_requested_by_type
      t.uuid :last_replay_requested_by_id
    end

    add_index :better_together_billing_events, %i[billable_owner_type billable_owner_id],
              name: 'idx_bt_billing_events_owner'
    add_index :better_together_billing_events, %i[processor event_id],
              unique: true,
              name: 'idx_bt_billing_events_processor_event'
    add_index :better_together_billing_events, :processing_status,
              name: 'idx_bt_billing_events_processing_status'
    add_index :better_together_billing_events, :last_attempted_at,
              name: 'idx_bt_billing_events_last_attempted_at'
    add_index :better_together_billing_events, :payload_redacted_at,
              name: 'idx_bt_billing_events_payload_redacted_at'
    add_index :better_together_billing_events, :dead_lettered_at,
              name: 'idx_bt_billing_events_dead_lettered_at'
    add_index :better_together_billing_events,
              %i[last_replay_requested_by_type last_replay_requested_by_id],
              name: 'idx_bt_billing_events_last_replay_requested_by'
  end
end
