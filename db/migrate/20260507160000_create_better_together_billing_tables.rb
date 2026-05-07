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

  def create_billing_subscriptions
    return if table_exists?(:better_together_billing_subscriptions)

    create_bt_table :billing_subscriptions do |t|
      t.references :community,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_communities, on_delete: :cascade },
                   index: { name: 'idx_bt_billing_subscriptions_community' }
      t.references :billing_plan,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_billing_plans, on_delete: :restrict },
                   index: { name: 'idx_bt_billing_subscriptions_plan' }
      t.string :processor, null: false, default: 'stripe'
      t.string :processor_subscription_id, null: false
      t.string :pay_customer_id
      t.string :status, null: false, default: 'incomplete'
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.boolean :cancel_at_period_end, null: false, default: false
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_billing_subscriptions, :processor_subscription_id,
              unique: true,
              name: 'idx_bt_billing_subscriptions_processor_id'
    add_index :better_together_billing_subscriptions, :status,
              name: 'idx_bt_billing_subscriptions_status'
    add_index :better_together_billing_subscriptions, %i[community_id status],
              name: 'idx_bt_billing_subscriptions_community_status'
  end

  def create_billing_events
    return if table_exists?(:better_together_billing_events)

    create_bt_table :billing_events do |t|
      t.references :community,
                   type: :uuid,
                   null: true,
                   foreign_key: { to_table: :better_together_communities, on_delete: :nullify },
                   index: { name: 'idx_bt_billing_events_community' }
      t.references :billing_subscription,
                   type: :uuid,
                   null: true,
                   foreign_key: { to_table: :better_together_billing_subscriptions, on_delete: :nullify },
                   index: { name: 'idx_bt_billing_events_subscription' }
      t.string :processor, null: false, default: 'stripe'
      t.string :event_type, null: false
      t.string :event_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at
      t.string :processing_status, null: false, default: 'pending'
      t.text :error_message
    end

    add_index :better_together_billing_events, %i[processor event_id],
              unique: true,
              name: 'idx_bt_billing_events_processor_event'
    add_index :better_together_billing_events, :processing_status,
              name: 'idx_bt_billing_events_processing_status'
  end
end
