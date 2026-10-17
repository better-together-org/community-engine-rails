# frozen_string_literal: true

class CreateBetterTogetherBillingOneTimePayments < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_billing_one_time_payments)

    create_bt_table :billing_one_time_payments do |t|
      t.references :owner,
                   type: :uuid,
                   polymorphic: true,
                   null: false,
                   index: { name: 'idx_bt_billing_one_time_payments_owner' }
      t.references :billing_plan,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_billing_plans }
      t.string :stripe_checkout_session_id, null: false
      t.string :stripe_payment_intent_id
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.string :status, null: false, default: 'succeeded'
      t.jsonb :metadata, null: false, default: {}
      t.datetime :last_synced_at
    end

    add_index :better_together_billing_one_time_payments, :stripe_checkout_session_id,
              unique: true,
              name: 'idx_bt_billing_one_time_payments_checkout_session'
    add_index :better_together_billing_one_time_payments, :stripe_payment_intent_id,
              name: 'idx_bt_billing_one_time_payments_payment_intent'
  end
end
